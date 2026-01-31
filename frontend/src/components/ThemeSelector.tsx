import { cn } from "@/lib/utils";
import { Sparkles, Heart, PartyPopper, Star } from "lucide-react";

export type WishTheme = "default" | "birthday" | "love" | "celebration";

interface ThemeSelectorProps {
  value: WishTheme;
  onChange: (theme: WishTheme) => void;
}

const themes: { value: WishTheme; label: string; icon: React.ComponentType<{ className?: string }> }[] = [
  { value: "default", label: "Default", icon: Sparkles },
  { value: "birthday", label: "Birthday", icon: PartyPopper },
  { value: "love", label: "Love", icon: Heart },
  { value: "celebration", label: "Celebration", icon: Star },
];

export function ThemeSelector({ value, onChange }: ThemeSelectorProps) {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
      {themes.map((theme) => {
        const Icon = theme.icon;
        const isSelected = value === theme.value;
        return (
          <button
            key={theme.value}
            type="button"
            onClick={() => onChange(theme.value)}
            className={cn(
              `theme-${theme.value}`,
              "relative flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all duration-200 overflow-hidden",
              isSelected
                ? "border-primary shadow-card scale-[1.02]"
                : "border-transparent hover:scale-[1.01]"
            )}
          >
            {/* Theme gradient background */}
            <div className="absolute inset-0 theme-gradient opacity-20" />
            
            <div
              className={cn(
                "relative z-10 w-10 h-10 rounded-full flex items-center justify-center transition-all duration-200",
                isSelected ? "theme-gradient text-primary-foreground shadow-soft" : "bg-secondary"
              )}
            >
              <Icon className="w-5 h-5" />
            </div>
            <span
              className={cn(
                "relative z-10 text-sm font-medium transition-colors",
                isSelected ? "text-foreground" : "text-muted-foreground"
              )}
            >
              {theme.label}
            </span>
            {isSelected && (
              <div className="absolute top-2 right-2 w-2 h-2 rounded-full bg-primary animate-pulse" />
            )}
          </button>
        );
      })}
    </div>
  );
}
