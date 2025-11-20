"use client";

interface ThemeToggleProps {
  onToggle: () => void;
  currentTheme: "light" | "dark";
}

export default function ThemeToggle({
  onToggle,
  currentTheme,
}: ThemeToggleProps) {
  return (
    <button
      onClick={onToggle}
      className="fixed top-4 right-4 z-50 bg-white/20 dark:bg-black/20 backdrop-blur-sm 
               rounded-full p-3 text-2xl hover:scale-110 transition-all duration-200 
               border border-white/20"
      title="Alterar tema"
    >
      {currentTheme === "dark" ? "☀️" : "🌙"}
    </button>
  );
}
