import { cn } from "@/lib/utils";
import { WishTheme } from "./ThemeSelector";
import { Heart, Sparkles, Star, PartyPopper } from "lucide-react";

interface WishCardProps {
  title?: string;
  message: string;
  theme: WishTheme;
  images?: string[];
  remainingViews?: number;
  className?: string;
}

const themeIcons: Record<WishTheme, React.ComponentType<{ className?: string }>> = {
  default: Sparkles,
  birthday: PartyPopper,
  love: Heart,
  celebration: Star,
};

export function WishCard({
  title,
  message,
  theme,
  images = [],
  remainingViews,
  className,
}: WishCardProps) {
  const ThemeIcon = themeIcons[theme];

  return (
    <div
      className={cn(
        `theme-${theme}`,
        "relative rounded-2xl overflow-hidden shadow-card",
        className
      )}
    >
      {/* Background gradient */}
      <div className="absolute inset-0 theme-gradient opacity-10" />
      
      {/* Decorative elements */}
      <div className="absolute top-4 right-4 opacity-20">
        <ThemeIcon className="w-20 h-20 animate-float" />
      </div>

      <div className="relative z-10 p-8 gradient-card">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6">
          <div className="w-12 h-12 rounded-full theme-gradient flex items-center justify-center shadow-soft">
            <ThemeIcon className="w-6 h-6 text-primary-foreground" />
          </div>
          {title && (
            <h1 className="text-2xl md:text-3xl font-display font-bold text-foreground">
              {title}
            </h1>
          )}
        </div>

        {/* Message */}
        <div className="mb-8">
          <p className="text-lg md:text-xl text-foreground leading-relaxed whitespace-pre-wrap">
            {message}
          </p>
        </div>

        {/* Images */}
        {images.length > 0 && (
          <div className={cn(
            "grid gap-3 mb-6",
            images.length === 1 && "grid-cols-1",
            images.length === 2 && "grid-cols-2",
            images.length >= 3 && "grid-cols-2 md:grid-cols-3"
          )}>
            {images.map((src, index) => (
              <div
                key={index}
                className={cn(
                  "relative rounded-xl overflow-hidden shadow-soft",
                  images.length === 1 ? "aspect-video" : "aspect-square"
                )}
              >
                <img
                  src={src}
                  alt={`Wish image ${index + 1}`}
                  className="w-full h-full object-cover"
                  loading="lazy"
                />
              </div>
            ))}
          </div>
        )}

        {/* Remaining views warning */}
        {remainingViews === 0 && (
          <div className="mt-6 p-4 rounded-xl bg-accent/20 border border-accent/30 text-center animate-fade-in">
            <p className="text-sm text-accent-foreground font-medium">
              ✨ This wish will disappear after this view ✨
            </p>
          </div>
        )}
      </div>

      {/* Floating decorations for themes */}
      {theme === "love" && (
        <>
          <Heart className="absolute top-[20%] left-[10%] w-6 h-6 text-primary/20 animate-float" style={{ animationDelay: "0.5s" }} />
          <Heart className="absolute bottom-[30%] right-[15%] w-4 h-4 text-primary/15 animate-float" style={{ animationDelay: "1s" }} />
        </>
      )}
      {theme === "celebration" && (
        <>
          <Star className="absolute top-[15%] right-[20%] w-5 h-5 text-accent/30 animate-sparkle" />
          <Star className="absolute bottom-[25%] left-[12%] w-4 h-4 text-accent/20 animate-sparkle" style={{ animationDelay: "0.7s" }} />
        </>
      )}
    </div>
  );
}
