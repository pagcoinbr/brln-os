import { useEffect, useState } from "react";
import { useRouter } from "next/router";

export function useSetupCheck() {
  const router = useRouter();
  const [setupComplete, setSetupComplete] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    checkSetup();
  }, []);

  const checkSetup = async () => {
    try {
      const response = await fetch("/api/v1/setup/check");
      const data = await response.json();
      setSetupComplete(data.setupComplete);

      // Redireciona para login se setup não está completo
      if (!data.setupComplete) {
        router.push("/install");
      }
    } catch (error) {
      console.error("Erro ao verificar setup:", error);
      setSetupComplete(false);
    } finally {
      setIsLoading(false);
    }
  };

  return { setupComplete, isLoading };
}
