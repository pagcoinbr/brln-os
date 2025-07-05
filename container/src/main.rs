use anyhow::{Context, Result};
use chrono::Utc;
use clap::Parser;
use colored::*;
use dialoguer::{theme::ColorfulTheme, Confirm, Select};
use indicatif::{ProgressBar, ProgressStyle};
use indexmap::IndexMap;
use log::{debug, error, info, warn};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use subprocess::{Exec, Redirection};
use walkdir::WalkDir;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Enable verbose output
    #[arg(short, long)]
    verbose: bool,
    
    /// Mode of operation
    #[arg(short, long, default_value = "interactive")]
    mode: String,
    
    /// Services to run (comma-separated)
    #[arg(short, long)]
    services: Option<String>,
    
    /// Include dependencies automatically
    #[arg(short, long)]
    deps: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ServiceConfig {
    username: Option<String>,
    uid: Option<u32>,
    groupname: Option<String>,
    gid: Option<u32>,
    description: Option<String>,
    data_dir: Option<String>,
    dockerfile: Option<String>,
    config_files: Option<Vec<String>>,
    binaries: Option<Vec<String>>,
    ports: Option<Vec<String>>,
    special_dirs: Option<Vec<String>>,
}

#[derive(Debug, Clone)]
struct DockerComposeService {
    name: String,
    depends_on: Vec<String>,
    ports: Vec<String>,
    volumes: Vec<String>,
    environment: HashMap<String, String>,
}

#[derive(Debug)]
struct ServiceManager {
    services: IndexMap<String, ServiceConfig>,
    docker_compose_services: IndexMap<String, DockerComposeService>,
    dependencies: HashMap<String, Vec<String>>,
    base_path: PathBuf,
}

impl ServiceManager {
    fn new(base_path: PathBuf) -> Self {
        Self {
            services: IndexMap::new(),
            docker_compose_services: IndexMap::new(),
            dependencies: HashMap::new(),
            base_path,
        }
    }

    /// Descobrir serviços do docker-compose.yml
    fn discover_docker_compose_services(&mut self) -> Result<()> {
        log_info("Analisando docker-compose.yml...");
        
        let compose_path = self.base_path.join("docker-compose.yml");
        if !compose_path.exists() {
            return Err(anyhow::anyhow!("docker-compose.yml não encontrado no diretório atual"));
        }

        let content = fs::read_to_string(&compose_path)
            .context("Erro ao ler docker-compose.yml")?;
        
        let compose_data: serde_yaml::Value = serde_yaml::from_str(&content)
            .context("Erro ao parsear docker-compose.yml")?;

        if let Some(services) = compose_data.get("services").and_then(|s| s.as_mapping()) {
            for (service_name, service_config) in services {
                let name = service_name.as_str().unwrap_or_default().to_string();
                
                // Extrair depends_on
                let depends_on = if let Some(deps) = service_config.get("depends_on") {
                    if let Some(deps_array) = deps.as_sequence() {
                        deps_array.iter()
                            .filter_map(|d| d.as_str())
                            .map(|s| s.to_string())
                            .collect()
                    } else if let Some(deps_map) = deps.as_mapping() {
                        deps_map.keys()
                            .filter_map(|k| k.as_str())
                            .map(|s| s.to_string())
                            .collect()
                    } else {
                        vec![]
                    }
                } else {
                    vec![]
                };

                // Extrair portas
                let ports = if let Some(ports_val) = service_config.get("ports") {
                    if let Some(ports_array) = ports_val.as_sequence() {
                        ports_array.iter()
                            .filter_map(|p| p.as_str())
                            .map(|s| s.to_string())
                            .collect()
                    } else {
                        vec![]
                    }
                } else {
                    vec![]
                };

                // Extrair volumes
                let volumes = if let Some(vols_val) = service_config.get("volumes") {
                    if let Some(vols_array) = vols_val.as_sequence() {
                        vols_array.iter()
                            .filter_map(|v| v.as_str())
                            .map(|s| s.to_string())
                            .collect()
                    } else {
                        vec![]
                    }
                } else {
                    vec![]
                };

                // Extrair environment
                let environment = if let Some(env_val) = service_config.get("environment") {
                    if let Some(env_map) = env_val.as_mapping() {
                        env_map.iter()
                            .filter_map(|(k, v)| {
                                Some((
                                    k.as_str()?.to_string(),
                                    v.as_str().unwrap_or_default().to_string()
                                ))
                            })
                            .collect()
                    } else {
                        HashMap::new()
                    }
                } else {
                    HashMap::new()
                };

                let docker_service = DockerComposeService {
                    name: name.clone(),
                    depends_on: depends_on.clone(),
                    ports,
                    volumes,
                    environment,
                };

                self.docker_compose_services.insert(name.clone(), docker_service);
                
                if !depends_on.is_empty() {
                    self.dependencies.insert(name, depends_on);
                }
            }
        }

        log_info(&format!("Encontrados {} serviços no docker-compose.yml", 
            self.docker_compose_services.len()));
        
        Ok(())
    }

    /// Descobrir serviços através dos arquivos service.json
    fn discover_services(&mut self) -> Result<()> {
        log_info("Descobrindo serviços automaticamente...");
        
        for entry in WalkDir::new(&self.base_path)
            .max_depth(2)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if entry.file_name() == "service.json" {
                let service_dir = entry.path().parent()
                    .and_then(|p| p.file_name())
                    .and_then(|n| n.to_str())
                    .unwrap_or_default();
                
                if service_dir.is_empty() {
                    continue;
                }

                match self.load_service_config(entry.path()) {
                    Ok(config) => {
                        self.services.insert(service_dir.to_string(), config);
                        log_debug(&format!("Serviço {} adicionado à lista", service_dir));
                    }
                    Err(e) => {
                        log_warning(&format!("Erro ao carregar {}: {}", entry.path().display(), e));
                    }
                }
            }
        }

        if self.services.is_empty() {
            return Err(anyhow::anyhow!("Nenhum serviço encontrado. Certifique-se de que existem arquivos service.json nos diretórios dos serviços"));
        }

        log_info(&format!("Descobertos {} serviços com configuração", self.services.len()));
        Ok(())
    }

    fn load_service_config(&self, path: &Path) -> Result<ServiceConfig> {
        let content = fs::read_to_string(path)
            .with_context(|| format!("Erro ao ler {}", path.display()))?;
        
        let config: ServiceConfig = serde_json::from_str(&content)
            .with_context(|| format!("Erro ao parsear JSON em {}", path.display()))?;
        
        Ok(config)
    }

    /// Resolver dependências de um serviço
    fn resolve_dependencies(&self, service: &str) -> Vec<String> {
        let mut resolved = Vec::new();
        let mut visited = HashSet::new();
        let mut stack = vec![service.to_string()];

        while let Some(current) = stack.pop() {
            if visited.contains(&current) {
                continue;
            }
            
            visited.insert(current.clone());
            
            if let Some(deps) = self.dependencies.get(&current) {
                for dep in deps {
                    if !visited.contains(dep) {
                        stack.push(dep.clone());
                    }
                }
            }
            
            resolved.push(current);
        }

        // Inverter para dependências primeiro
        resolved.reverse();
        resolved
    }

    /// Criar usuários e grupos do sistema
    async fn create_users_and_groups(&self) -> Result<()> {
        log_info("Criando usuários e grupos do sistema...");
        
        let pb = ProgressBar::new(self.services.len() as u64);
        pb.set_style(ProgressStyle::default_bar()
            .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} {msg}")
            .unwrap());

        for (service_name, config) in &self.services {
            pb.set_message(format!("Processando {}", service_name));
            
            if let (Some(username), Some(uid), Some(groupname), Some(gid)) = 
                (&config.username, &config.uid, &config.groupname, &config.gid) {
                
                // Criar grupo
                if !self.group_exists(groupname)? {
                    self.create_group(groupname, *gid).await?;
                    log_info(&format!("Grupo {} criado com GID {}", groupname, gid));
                }

                // Criar usuário
                if !self.user_exists(username)? {
                    self.create_user(username, *uid, groupname, 
                        config.description.as_deref().unwrap_or("Sistema")).await?;
                    log_info(&format!("Usuário {} criado com UID {}", username, uid));
                }
            }
            
            pb.inc(1);
        }
        
        pb.finish_with_message("Usuários e grupos criados");
        Ok(())
    }

    fn user_exists(&self, username: &str) -> Result<bool> {
        let output = Command::new("id")
            .arg(username)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()?;
        
        Ok(output.success())
    }

    fn group_exists(&self, groupname: &str) -> Result<bool> {
        let output = Command::new("getent")
            .args(&["group", groupname])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()?;
        
        Ok(output.success())
    }

    async fn create_group(&self, groupname: &str, gid: u32) -> Result<()> {
        let status = Command::new("sudo")
            .args(&["groupadd", "-g", &gid.to_string(), groupname])
            .status()?;
        
        if !status.success() {
            return Err(anyhow::anyhow!("Falha ao criar grupo {}", groupname));
        }
        
        Ok(())
    }

    async fn create_user(&self, username: &str, uid: u32, groupname: &str, description: &str) -> Result<()> {
        let status = Command::new("sudo")
            .args(&[
                "useradd", "-r", "-u", &uid.to_string(),
                "-g", groupname, "-c", description,
                "-s", "/bin/false", username
            ])
            .status()?;
        
        if !status.success() {
            return Err(anyhow::anyhow!("Falha ao criar usuário {}", username));
        }
        
        Ok(())
    }

    /// Criar diretórios de dados
    async fn create_data_directories(&self) -> Result<()> {
        log_info("Criando diretórios de dados...");
        
        // Criar diretório base /data
        fs::create_dir_all("/data").context("Erro ao criar /data")?;

        for (service_name, config) in &self.services {
            if let (Some(username), Some(uid), Some(gid), Some(data_dir)) = 
                (&config.username, &config.uid, &config.gid, &config.data_dir) {
                
                // Criar diretório principal
                fs::create_dir_all(data_dir)
                    .with_context(|| format!("Erro ao criar {}", data_dir))?;
                
                self.set_ownership(data_dir, *uid, *gid).await?;
                self.set_permissions(data_dir, "755").await?;
                
                log_info(&format!("Diretório {} criado para {}", data_dir, username));
                
                // Criar diretórios especiais
                if let Some(special_dirs) = &config.special_dirs {
                    for special_dir in special_dirs {
                        let full_path = format!("{}/{}", data_dir, special_dir);
                        fs::create_dir_all(&full_path)
                            .with_context(|| format!("Erro ao criar {}", full_path))?;
                        log_debug(&format!("Criado diretório especial: {}", full_path));
                    }
                    
                    // Reajustar permissões após criar estruturas especiais
                    self.set_ownership(data_dir, *uid, *gid).await?;
                    self.set_permissions(data_dir, "755").await?;
                }
            }
        }
        
        Ok(())
    }

    async fn set_ownership(&self, path: &str, uid: u32, gid: u32) -> Result<()> {
        let ownership = format!("{}:{}", uid, gid);
        let status = Command::new("sudo")
            .args(&["chown", "-R", &ownership, path])
            .status()?;
        
        if !status.success() {
            return Err(anyhow::anyhow!("Falha ao definir propriedade de {}", path));
        }
        
        Ok(())
    }

    async fn set_permissions(&self, path: &str, mode: &str) -> Result<()> {
        let status = Command::new("sudo")
            .args(&["chmod", "-R", mode, path])
            .status()?;
        
        if !status.success() {
            return Err(anyhow::anyhow!("Falha ao definir permissões de {}", path));
        }
        
        Ok(())
    }

    /// Configurar arquivos de configuração
    async fn setup_config_files(&self) -> Result<()> {
        log_info("Configurando arquivos de configuração...");
        
        for (service_name, config) in &self.services {
            if let (Some(uid), Some(gid), Some(data_dir), Some(config_files)) = 
                (&config.uid, &config.gid, &config.data_dir, &config.config_files) {
                
                for config_file in config_files {
                    let source_path = self.base_path.join(service_name).join(config_file);
                    
                    let dest_file = if config_file.ends_with(".example") {
                        config_file.trim_end_matches(".example")
                    } else {
                        config_file
                    };
                    
                    let dest_path = format!("{}/{}", data_dir, dest_file);
                    
                    if source_path.exists() {
                        self.copy_config_file(&source_path, &dest_path, *uid, *gid, dest_file).await?;
                        log_info(&format!("Arquivo {} configurado para {}", dest_file, service_name));
                    } else {
                        log_warning(&format!("Arquivo de configuração não encontrado: {}", source_path.display()));
                    }
                }
            }
        }
        
        Ok(())
    }

    async fn copy_config_file(&self, source: &Path, dest: &str, uid: u32, gid: u32, filename: &str) -> Result<()> {
        // Copiar arquivo
        let status = Command::new("sudo")
            .args(&["cp", &source.to_string_lossy(), dest])
            .status()?;
        
        if !status.success() {
            return Err(anyhow::anyhow!("Falha ao copiar {}", source.display()));
        }

        // Definir propriedade
        let ownership = format!("{}:{}", uid, gid);
        Command::new("sudo")
            .args(&["chown", &ownership, dest])
            .status()?;

        // Definir permissões baseadas no tipo de arquivo
        let mode = match filename {
            "password.txt" => "600",
            f if f.ends_with(".sh") => "755",
            _ => "644",
        };
        
        Command::new("sudo")
            .args(&["chmod", mode, dest])
            .status()?;
        
        Ok(())
    }

    /// Verificar recursos necessários
    fn verify_resources(&self) -> Result<()> {
        log_info("Verificando recursos necessários...");
        
        let mut missing_dockerfiles = Vec::new();
        let mut missing_binaries = Vec::new();
        let mut total_dockerfiles = 0;
        let mut total_binaries = 0;

        for (service_name, config) in &self.services {
            // Verificar Dockerfile
            if let Some(dockerfile) = &config.dockerfile {
                total_dockerfiles += 1;
                let dockerfile_path = self.base_path.join(service_name).join(dockerfile);
                if !dockerfile_path.exists() {
                    missing_dockerfiles.push(dockerfile_path.to_string_lossy().to_string());
                }
            }

            // Verificar binários
            if let Some(binaries) = &config.binaries {
                for binary in binaries {
                    total_binaries += 1;
                    let binary_path = self.base_path.join(service_name).join(binary);
                    if !binary_path.exists() {
                        missing_binaries.push(binary_path.to_string_lossy().to_string());
                    }
                }
            }
        }

        // Relatórios
        log_info(&format!("Dockerfiles: {}/{} encontrados", 
            total_dockerfiles - missing_dockerfiles.len(), total_dockerfiles));
        
        if !missing_dockerfiles.is_empty() {
            log_warning("Dockerfiles não encontrados:");
            for dockerfile in &missing_dockerfiles {
                println!("  - {}", dockerfile);
            }
        }

        log_info(&format!("Binários: {}/{} encontrados", 
            total_binaries - missing_binaries.len(), total_binaries));
        
        if !missing_binaries.is_empty() {
            log_warning("Binários não encontrados:");
            for binary in &missing_binaries {
                println!("  - {}", binary);
            }
        }

        Ok(())
    }

    /// Menu interativo para seleção de serviços
    fn show_interactive_menu(&self) -> Result<Vec<String>> {
        println!("\n{}", "=== Menu de Seleção de Serviços ===".blue().bold());
        println!("Serviços disponíveis:\n");

        let mut items = Vec::new();
        for (i, (service_name, config)) in self.services.iter().enumerate() {
            let description = config.description.as_deref().unwrap_or("Sem descrição");
            let ports = if let Some(ports) = &config.ports {
                format!(" (portas: {})", ports.join(", "))
            } else {
                String::new()
            };

            let deps = if let Some(deps) = self.dependencies.get(service_name) {
                format!(" [deps: {}]", deps.join(", "))
            } else {
                String::new()
            };

            let item_text = format!("{:<15} - {}{}{}", service_name, description, ports, deps);
            items.push(item_text);
        }

        // Adicionar opções especiais
        items.push("Todos os serviços".to_string());
        items.push("Detecção automática".to_string());
        items.push("Modo de teste individual".to_string());

        let selection = Select::with_theme(&ColorfulTheme::default())
            .with_prompt("Escolha uma opção")
            .items(&items)
            .default(0)
            .interact()?;

        let service_names: Vec<String> = self.services.keys().cloned().collect();

        match selection {
            n if n < service_names.len() => {
                let selected_service = &service_names[n];
                
                // Perguntar se incluir dependências
                let include_deps = Confirm::with_theme(&ColorfulTheme::default())
                    .with_prompt("Incluir dependências automaticamente?")
                    .default(true)
                    .interact()?;

                if include_deps {
                    Ok(self.resolve_dependencies(selected_service))
                } else {
                    Ok(vec![selected_service.clone()])
                }
            }
            n if n == service_names.len() => Ok(service_names), // Todos
            n if n == service_names.len() + 1 => { // Auto
                Ok(self.auto_detect_services())
            }
            _ => { // Teste individual
                self.individual_test_menu()
            }
        }
    }

    fn auto_detect_services(&self) -> Vec<String> {
        self.services.iter()
            .filter_map(|(name, config)| {
                if let Some(dockerfile) = &config.dockerfile {
                    let dockerfile_path = self.base_path.join(name).join(dockerfile);
                    if dockerfile_path.exists() {
                        Some(name.clone())
                    } else {
                        None
                    }
                } else {
                    None
                }
            })
            .collect()
    }

    fn individual_test_menu(&self) -> Result<Vec<String>> {
        println!("\n{}", "=== Modo de Teste Individual ===".cyan().bold());
        println!("Escolha um serviço para teste isolado:\n");

        let service_names: Vec<String> = self.services.keys().cloned().collect();
        let items: Vec<String> = service_names.iter()
            .map(|name| {
                let config = &self.services[name];
                let description = config.description.as_deref().unwrap_or("Sem descrição");
                format!("{} - {}", name, description)
            })
            .collect();

        let selection = Select::with_theme(&ColorfulTheme::default())
            .with_prompt("Escolha um serviço para teste")
            .items(&items)
            .interact()?;

        let selected_service = &service_names[selection];
        
        println!("\n{}", format!("Serviço selecionado: {}", selected_service).green().bold());
        
        // Mostrar dependências se existirem
        if let Some(deps) = self.dependencies.get(selected_service) {
            println!("Dependências necessárias: {}", deps.join(", "));
            
            let include_deps = Confirm::with_theme(&ColorfulTheme::default())
                .with_prompt("Incluir dependências?")
                .default(true)
                .interact()?;

            if include_deps {
                Ok(self.resolve_dependencies(selected_service))
            } else {
                Ok(vec![selected_service.clone()])
            }
        } else {
            Ok(vec![selected_service.clone()])
        }
    }

    /// Executar docker-compose
    async fn run_docker_compose(&self, services: &[String]) -> Result<()> {
        log_info(&format!("Iniciando containers para os serviços: {}", services.join(", ")));

        // Parar containers existentes
        log_info("Parando containers existentes...");
        let _ = Command::new("docker-compose")
            .args(&["down", "-v"])
            .current_dir(&self.base_path)
            .status();

        // Build dos serviços selecionados
        log_info("Construindo imagens...");
        let mut build_cmd = Command::new("docker-compose");
        build_cmd.arg("build").current_dir(&self.base_path);
        
        for service in services {
            build_cmd.arg(service);
        }

        let build_status = build_cmd.status()?;
        if !build_status.success() {
            return Err(anyhow::anyhow!("Falha no build dos containers"));
        }

        log_info("Build concluído com sucesso");

        // Iniciar serviços
        log_info("Iniciando serviços...");
        let mut up_cmd = Command::new("docker-compose");
        up_cmd.args(&["up", "-d"]).current_dir(&self.base_path);
        
        for service in services {
            up_cmd.arg(service);
        }

        let up_status = up_cmd.status()?;
        if !up_status.success() {
            return Err(anyhow::anyhow!("Falha ao iniciar containers"));
        }

        log_info("Containers iniciados com sucesso");

        // Mostrar status
        println!("\n{}", "=== Status dos Containers ===".green().bold());
        Command::new("docker-compose")
            .arg("ps")
            .current_dir(&self.base_path)
            .status()?;

        // Mostrar informações dos serviços
        println!("\n{}", "=== Informações dos Serviços ===".cyan().bold());
        for service in services {
            if let Some(config) = self.services.get(service) {
                let description = config.description.as_deref().unwrap_or("Sem descrição");
                println!("{}: {}", service.blue().bold(), description);
                
                if let Some(ports) = &config.ports {
                    println!("  Portas: {}", ports.join(", "));
                }
            }
        }

        Ok(())
    }
}

// Funções auxiliares de logging
fn log_info(msg: &str) {
    println!("{} {}", "[INFO]".green().bold(), msg);
}

fn log_warning(msg: &str) {
    println!("{} {}", "[WARNING]".yellow().bold(), msg);
}

fn log_error(msg: &str) {
    println!("{} {}", "[ERROR]".red().bold(), msg);
}

fn log_debug(msg: &str) {
    if log::log_enabled!(log::Level::Debug) {
        println!("{} {}", "[DEBUG]".cyan(), msg);
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();
    
    // Configurar logging
    if args.verbose {
        env_logger::Builder::from_default_env()
            .filter_level(log::LevelFilter::Debug)
            .init();
    } else {
        env_logger::Builder::from_default_env()
            .filter_level(log::LevelFilter::Info)
            .init();
    }

    // Verificar dependências
    if which::which("docker-compose").is_err() {
        return Err(anyhow::anyhow!("docker-compose não encontrado no PATH"));
    }

    if which::which("jq").is_err() {
        log_warning("jq não encontrado, algumas funcionalidades podem estar limitadas");
    }

    let base_path = std::env::current_dir()
        .context("Erro ao obter diretório atual")?;

    if !base_path.join("docker-compose.yml").exists() {
        return Err(anyhow::anyhow!("docker-compose.yml não encontrado. Execute este programa no diretório container/"));
    }

    let mut service_manager = ServiceManager::new(base_path);

    println!("{}", "=== Configurador Inteligente de Docker Compose (Rust) ===".blue().bold());

    // Descobrir serviços
    service_manager.discover_docker_compose_services()?;
    service_manager.discover_services()?;

    // Executar configurações básicas
    service_manager.create_users_and_groups().await?;
    service_manager.create_data_directories().await?;
    service_manager.setup_config_files().await?;
    service_manager.verify_resources()?;

    // Selecionar e executar serviços
    let selected_services = if let Some(services_arg) = args.services {
        services_arg.split(',').map(|s| s.trim().to_string()).collect()
    } else if args.mode == "auto" {
        service_manager.auto_detect_services()
    } else {
        service_manager.show_interactive_menu()?
    };

    if selected_services.is_empty() {
        return Err(anyhow::anyhow!("Nenhum serviço selecionado"));
    }

    log_info(&format!("Serviços selecionados: {}", selected_services.join(", ")));

    // Executar docker-compose
    service_manager.run_docker_compose(&selected_services).await?;

    println!("\n{}", "=== Configuração concluída com sucesso ===".green().bold());
    println!("Sistema de logs ativo em: container/logs/");
    println!("Use 'docker-compose logs -f [serviço]' para acompanhar logs");

    Ok(())
}
