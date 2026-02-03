import { useState, useEffect } from "react";
import { cn } from "@/lib/utils";
import { WishTheme } from "./ThemeSelector";
import { CelebrationItem } from "./CelebrationItems";
import { ThemeAnimations, CelebrationEffects } from "./animations";
import { 
  Heart, Sparkles, Star, PartyPopper, 
  Flower2, HeartHandshake, Award, Gift, Music, Calendar,
  Candy, Cake, CircleDot
} from "lucide-react";

interface WishCardProps {
  title?: string;
  message: string;
  theme: WishTheme;
  images?: string[];
  celebrationItems?: CelebrationItem[];
  remainingViews?: number;
  className?: string;
  isPreview?: boolean;
}

const themeIcons: Record<WishTheme, React.ComponentType<{ className?: string }>> = {
  default: Sparkles,
  birthday: PartyPopper,
  love: Heart,
  celebration: Star,
  wedding: Flower2,
  valentine: HeartHandshake,
  congratulations: Award,
  appreciation: Gift,
  festival: Music,
  event: Calendar,
};

const itemIcons: Record<CelebrationItem["type"], React.ComponentType<{ className?: string }>> = {
  chocolates: Candy,
  cake: Cake,
  balloons: CircleDot,
  poppers: PartyPopper,
  gifts: Gift,
  confetti: Sparkles,
};

export function WishCard({
  title,
  message,
  theme,
  images = [],
  celebrationItems = [],
  remainingViews,
  className,
  isPreview = false,
}: WishCardProps) {
  const [isAnimationActive, setIsAnimationActive] = useState(false);
  const [showContent, setShowContent] = useState(false);
  const ThemeIcon = themeIcons[theme];

  // Trigger animations on mount (when card opens)
  useEffect(() => {
    const animationTimer = setTimeout(() => setIsAnimationActive(true), 100);
    const contentTimer = setTimeout(() => setShowContent(true), 400);
    
    return () => {
      clearTimeout(animationTimer);
      clearTimeout(contentTimer);
    };
  }, []);

  return (
    <div
      className={cn(
        `theme-${theme}`,
        "relative rounded-2xl overflow-hidden shadow-card",
        "transform transition-all duration-500",
        showContent ? "opacity-100 scale-100" : "opacity-0 scale-95",
        className
      )}
    >
      {/* Theme-specific background animations */}
      <ThemeAnimations theme={theme} isActive={isAnimationActive} />
      
      {/* Celebration item effects */}
      <CelebrationEffects 
        items={celebrationItems} 
        isActive={isAnimationActive && !isPreview}
      />

      {/* Background gradient */}
      <div className="absolute inset-0 theme-gradient opacity-10" />
      
      {/* Animated decorative corner element */}
      <div className="absolute top-4 right-4 opacity-20">
        <ThemeIcon className={cn(
          "w-20 h-20",
          theme === "love" || theme === "valentine" ? "animate-heartbeat" : "animate-float"
        )} />
      </div>

      <div className="relative z-10 p-8 gradient-card">
        {/* Header with entrance animation */}
        <div className={cn(
          "flex items-center gap-3 mb-6",
          "transform transition-all duration-700 delay-200",
          showContent ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"
        )}>
          <div className={cn(
            "w-12 h-12 rounded-full theme-gradient flex items-center justify-center shadow-soft",
            "animate-icon-entrance"
          )}>
            <ThemeIcon className="w-6 h-6 text-primary-foreground" />
          </div>
          {title && (
            <h1 className="text-2xl md:text-3xl font-display font-bold text-foreground animate-text-reveal">
              {title}
            </h1>
          )}
        </div>

        {/* Message with staggered reveal */}
        <div className={cn(
          "mb-8",
          "transform transition-all duration-700 delay-400",
          showContent ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"
        )}>
          <p className="text-lg md:text-xl text-foreground leading-relaxed whitespace-pre-wrap">
            {message}
          </p>
        </div>

        {/* Images with fade-in effect */}
        {images.length > 0 && (
          <div className={cn(
            "grid gap-3 mb-6",
            "transform transition-all duration-700 delay-500",
            showContent ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4",
            images.length === 1 && "grid-cols-1",
            images.length === 2 && "grid-cols-2",
            images.length >= 3 && "grid-cols-2 md:grid-cols-3"
          )}>
            {images.map((src, index) => (
              <div
                key={index}
                className={cn(
                  "relative rounded-xl overflow-hidden shadow-soft",
                  "transform transition-all duration-500",
                  "hover:scale-[1.02] hover:shadow-card",
                  images.length === 1 ? "aspect-video" : "aspect-square"
                )}
                style={{ transitionDelay: `${600 + index * 100}ms` }}
              >
                <img
                  src={src}
                  alt={`Wish image ${index + 1}`}
                  className="w-full h-full object-cover"
                  loading="lazy"
                />
                {/* Image shimmer effect */}
                <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent animate-shimmer" />
              </div>
            ))}
          </div>
        )}

        {/* Celebration Items with animated badges */}
        {celebrationItems.length > 0 && (
          <div className={cn(
            "mb-6 p-4 rounded-xl bg-background/50 backdrop-blur-sm",
            "transform transition-all duration-700 delay-600",
            showContent ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"
          )}>
            <p className="text-sm text-muted-foreground mb-3">Celebration includes:</p>
            <div className="flex flex-wrap gap-3">
              {celebrationItems.map((item, index) => {
                const Icon = itemIcons[item.type];
                return (
                  <div
                    key={item.id}
                    className={cn(
                      "flex items-center gap-2 px-3 py-2 rounded-lg bg-secondary/50",
                      "transform transition-all duration-300 hover:scale-105",
                      "animate-item-pop"
                    )}
                    style={{ animationDelay: `${700 + index * 100}ms` }}
                  >
                    <div 
                      className="w-6 h-6 rounded-full flex items-center justify-center animate-pulse-soft"
                      style={{ backgroundColor: item.color || 'hsl(var(--primary))' }}
                    >
                      <Icon className="w-3 h-3 text-white" />
                    </div>
                    <span className="text-sm font-medium">
                      {item.quantity}x {item.type.charAt(0).toUpperCase() + item.type.slice(1)}
                    </span>
                    {item.message && (
                      <span className="text-xs text-muted-foreground">"{item.message}"</span>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Remaining views warning with attention animation */}
        {remainingViews === 0 && (
          <div className={cn(
            "mt-6 p-4 rounded-xl bg-accent/20 border border-accent/30 text-center",
            "animate-attention-pulse"
          )}>
            <p className="text-sm text-accent-foreground font-medium">
              ✨ This wish will disappear after this view ✨
            </p>
          </div>
        )}
      </div>

      {/* Theme-specific floating decorations */}
      {theme === "love" && (
        <>
          <Heart className="absolute top-[20%] left-[10%] w-6 h-6 text-primary/20 animate-float" style={{ animationDelay: "0.5s" }} />
          <Heart className="absolute bottom-[30%] right-[15%] w-4 h-4 text-primary/15 animate-float" style={{ animationDelay: "1s" }} />
        </>
      )}
      {theme === "valentine" && (
        <>
          <Heart className="absolute top-[15%] left-[8%] w-8 h-8 text-primary/25 animate-heartbeat" />
          <Heart className="absolute bottom-[20%] right-[10%] w-5 h-5 text-primary/20 animate-heartbeat" style={{ animationDelay: "0.3s" }} />
          <HeartHandshake className="absolute top-[40%] right-[8%] w-6 h-6 text-primary/15 animate-float" />
        </>
      )}
      {theme === "wedding" && (
        <>
          <Flower2 className="absolute top-[15%] left-[12%] w-6 h-6 text-primary/20 animate-float" />
          <Flower2 className="absolute bottom-[25%] right-[10%] w-5 h-5 text-primary/15 animate-float" style={{ animationDelay: "0.8s" }} />
        </>
      )}
      {theme === "celebration" && (
        <>
          <Star className="absolute top-[15%] right-[20%] w-5 h-5 text-accent/30 animate-sparkle" />
          <Star className="absolute bottom-[25%] left-[12%] w-4 h-4 text-accent/20 animate-sparkle" style={{ animationDelay: "0.7s" }} />
        </>
      )}
      {theme === "festival" && (
        <>
          <Music className="absolute top-[18%] left-[10%] w-6 h-6 text-accent/25 animate-float" />
          <Sparkles className="absolute bottom-[22%] right-[12%] w-5 h-5 text-accent/20 animate-sparkle" />
        </>
      )}
      {theme === "congratulations" && (
        <>
          <Award className="absolute top-[12%] right-[15%] w-7 h-7 text-accent/25 animate-float" />
          <Star className="absolute bottom-[28%] left-[8%] w-4 h-4 text-accent/20 animate-sparkle" style={{ animationDelay: "0.5s" }} />
        </>
      )}
      {theme === "birthday" && (
        <>
          <PartyPopper className="absolute top-[10%] left-[8%] w-7 h-7 text-accent/30 animate-bounce-pop" />
          <PartyPopper className="absolute top-[15%] right-[10%] w-6 h-6 text-primary/25 animate-bounce-pop scale-x-[-1]" style={{ animationDelay: "0.5s" }} />
        </>
      )}
    </div>
  );
}
