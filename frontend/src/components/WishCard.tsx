import { cn } from "@/lib/utils";
import { WishTheme } from "./ThemeSelector";
import { CelebrationItem } from "./CelebrationItems";
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

        {/* Celebration Items */}
        {celebrationItems.length > 0 && (
          <div className="mb-6 p-4 rounded-xl bg-background/50 backdrop-blur-sm">
            <p className="text-sm text-muted-foreground mb-3">Celebration includes:</p>
            <div className="flex flex-wrap gap-3">
              {celebrationItems.map((item) => {
                const Icon = itemIcons[item.type];
                return (
                  <div
                    key={item.id}
                    className="flex items-center gap-2 px-3 py-2 rounded-lg bg-secondary/50"
                  >
                    <div 
                      className="w-6 h-6 rounded-full flex items-center justify-center"
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
    </div>
  );
}
