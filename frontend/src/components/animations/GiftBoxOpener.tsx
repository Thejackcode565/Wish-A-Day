import { useState, useEffect } from "react";
import { cn } from "@/lib/utils";
import { WishTheme } from "../ThemeSelector";
import { 
  Gift, Heart, PartyPopper, Star, Flower2, 
  HeartHandshake, Award, Music, Calendar, Sparkles 
} from "lucide-react";

interface GiftBoxOpenerProps {
  theme: WishTheme;
  onOpenComplete: () => void;
  isActive: boolean;
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

const themeColors: Record<WishTheme, { box: string; ribbon: string; glow: string }> = {
  default: { box: "#FFD700", ribbon: "#FF6B6B", glow: "#FFD700" },
  birthday: { box: "#FF69B4", ribbon: "#4ECDC4", glow: "#FF69B4" },
  love: { box: "#FF1744", ribbon: "#FFD700", glow: "#FF1744" },
  celebration: { box: "#FFD700", ribbon: "#FF6B6B", glow: "#FFD700" },
  wedding: { box: "#FFFFFF", ribbon: "#FFD700", glow: "#F8BBD9" },
  valentine: { box: "#FF1744", ribbon: "#FFB6C1", glow: "#FF1744" },
  congratulations: { box: "#FFD700", ribbon: "#FF6B6B", glow: "#FFD700" },
  appreciation: { box: "#4CAF50", ribbon: "#FFD700", glow: "#4CAF50" },
  festival: { box: "#9C27B0", ribbon: "#FFD700", glow: "#9C27B0" },
  event: { box: "#2196F3", ribbon: "#FFD700", glow: "#2196F3" },
};

export function GiftBoxOpener({ theme, onOpenComplete, isActive }: GiftBoxOpenerProps) {
  const [phase, setPhase] = useState<"closed" | "shaking" | "opening" | "opened" | "complete">("closed");
  const [showContent, setShowContent] = useState(false);
  
  const ThemeIcon = themeIcons[theme];
  const colors = themeColors[theme];

  useEffect(() => {
    if (!isActive) return;

    const sequence = [
      { phase: "shaking", delay: 500 },
      { phase: "opening", delay: 2000 },
      { phase: "opened", delay: 3500 },
      { phase: "complete", delay: 4500 },
    ];

    const timers = sequence.map(({ phase, delay }) =>
      setTimeout(() => {
        setPhase(phase as any);
        if (phase === "opening") {
          setShowContent(true);
        }
        if (phase === "complete") {
          setTimeout(onOpenComplete, 500);
        }
      }, delay)
    );

    return () => timers.forEach(clearTimeout);
  }, [isActive, onOpenComplete]);

  if (phase === "complete") return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm">
      {/* Theme-specific background particles */}
      <div className="absolute inset-0 overflow-hidden">
        {Array.from({ length: 20 }).map((_, i) => (
          <div
            key={i}
            className="absolute animate-float-particles"
            style={{
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
              animationDelay: `${Math.random() * 3}s`,
              animationDuration: `${4 + Math.random() * 2}s`,
            }}
          >
            <div 
              className="w-1 h-1 rounded-full opacity-60"
              style={{ backgroundColor: colors.glow }}
            />
          </div>
        ))}
      </div>

      {/* Gift box container */}
      <div className="relative">
        {/* Glow effect */}
        <div 
          className={cn(
            "absolute inset-0 rounded-2xl blur-xl transition-all duration-1000",
            phase === "shaking" && "animate-pulse",
            phase === "opening" && "scale-110 opacity-75",
            phase === "opened" && "scale-150 opacity-50"
          )}
          style={{ 
            backgroundColor: colors.glow,
            boxShadow: `0 0 60px ${colors.glow}`,
          }}
        />

        {/* Gift box */}
        <div 
          className={cn(
            "relative w-32 h-32 transition-all duration-1000 transform-gpu",
            phase === "shaking" && "animate-gift-shake",
            phase === "opening" && "scale-110",
            phase === "opened" && "scale-125"
          )}
        >
          {/* Box base */}
          <div 
            className={cn(
              "absolute inset-0 rounded-lg transition-all duration-700",
              phase === "opening" && "animate-box-open-bottom",
              phase === "opened" && "opacity-80"
            )}
            style={{ backgroundColor: colors.box }}
          >
            {/* Box shine */}
            <div className="absolute inset-2 rounded-md bg-gradient-to-br from-white/30 to-transparent" />
          </div>

          {/* Box lid */}
          <div 
            className={cn(
              "absolute inset-0 rounded-lg transition-all duration-700 origin-bottom",
              phase === "opening" && "animate-box-lid-open",
              phase === "opened" && "-rotate-45 -translate-y-8 translate-x-4"
            )}
            style={{ backgroundColor: colors.box }}
          >
            {/* Lid shine */}
            <div className="absolute inset-2 rounded-md bg-gradient-to-br from-white/40 to-transparent" />
          </div>

          {/* Ribbon horizontal */}
          <div 
            className={cn(
              "absolute top-1/2 left-0 right-0 h-4 -translate-y-1/2 transition-all duration-700",
              phase === "opening" && "animate-ribbon-break",
              phase === "opened" && "opacity-0"
            )}
            style={{ backgroundColor: colors.ribbon }}
          >
            <div className="absolute inset-1 bg-gradient-to-r from-white/30 via-transparent to-white/30" />
          </div>

          {/* Ribbon vertical */}
          <div 
            className={cn(
              "absolute left-1/2 top-0 bottom-0 w-4 -translate-x-1/2 transition-all duration-700",
              phase === "opening" && "animate-ribbon-break",
              phase === "opened" && "opacity-0"
            )}
            style={{ backgroundColor: colors.ribbon }}
          >
            <div className="absolute inset-1 bg-gradient-to-b from-white/30 via-transparent to-white/30" />
          </div>

          {/* Ribbon bow */}
          <div 
            className={cn(
              "absolute top-2 left-1/2 -translate-x-1/2 w-8 h-6 transition-all duration-700",
              phase === "opening" && "animate-bow-untie",
              phase === "opened" && "opacity-0 scale-0"
            )}
            style={{ backgroundColor: colors.ribbon }}
          >
            <div className="absolute inset-0.5 bg-gradient-to-br from-white/40 to-transparent rounded-sm" />
          </div>

          {/* Content reveal */}
          {showContent && (
            <div 
              className={cn(
                "absolute inset-0 flex items-center justify-center transition-all duration-1000",
                phase === "opened" ? "opacity-100 scale-100" : "opacity-0 scale-50"
              )}
            >
              <div className="relative">
                {/* Theme icon with glow */}
                <div 
                  className="absolute inset-0 blur-md animate-pulse"
                  style={{ color: colors.glow }}
                >
                  <ThemeIcon className="w-12 h-12" />
                </div>
                <ThemeIcon 
                  className={cn(
                    "w-12 h-12 relative z-10 animate-icon-emerge",
                    "drop-shadow-lg"
                  )}
                  style={{ color: colors.glow }}
                />
                
                {/* Sparkle burst */}
                <div className="absolute inset-0 animate-sparkle-burst">
                  {Array.from({ length: 8 }).map((_, i) => (
                    <div
                      key={i}
                      className="absolute w-1 h-1 bg-white rounded-full animate-sparkle-fly"
                      style={{
                        left: "50%",
                        top: "50%",
                        transform: `rotate(${i * 45}deg) translateY(-20px)`,
                        animationDelay: `${i * 0.1}s`,
                      }}
                    />
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Theme-specific celebration burst */}
        {phase === "opened" && (
          <div className="absolute inset-0 pointer-events-none">
            {theme === "birthday" && <BirthdayBurst />}
            {theme === "love" && <LoveBurst />}
            {theme === "celebration" && <CelebrationBurst />}
            {theme === "wedding" && <WeddingBurst />}
            {theme === "valentine" && <ValentineBurst />}
            {theme === "congratulations" && <CongratsBurst />}
            {theme === "appreciation" && <AppreciationBurst />}
            {theme === "festival" && <FestivalBurst />}
            {theme === "event" && <EventBurst />}
            {theme === "default" && <DefaultBurst />}
          </div>
        )}
      </div>
    </div>
  );
}

// Theme-specific celebration bursts
const BirthdayBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {/* Balloons */}
    {Array.from({ length: 6 }).map((_, i) => (
      <div
        key={`balloon-${i}`}
        className="absolute animate-balloon-burst"
        style={{
          left: `${20 + i * 10}%`,
          animationDelay: `${i * 0.1}s`,
        }}
      >
        <div 
          className="w-4 h-5 rounded-full"
          style={{ backgroundColor: ["#FF6B6B", "#4ECDC4", "#FFE66D"][i % 3] }}
        />
      </div>
    ))}
    {/* Confetti */}
    {Array.from({ length: 12 }).map((_, i) => (
      <div
        key={`confetti-${i}`}
        className="absolute w-1 h-1 animate-confetti-burst"
        style={{
          left: `${Math.random() * 100}%`,
          backgroundColor: ["#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3"][i % 4],
          animationDelay: `${i * 0.05}s`,
        }}
      />
    ))}
  </div>
);

const LoveBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {Array.from({ length: 8 }).map((_, i) => (
      <Heart
        key={i}
        className="absolute w-3 h-3 text-red-500 fill-red-500 animate-heart-burst"
        style={{
          left: `${Math.random() * 100}%`,
          top: `${Math.random() * 100}%`,
          animationDelay: `${i * 0.1}s`,
        }}
      />
    ))}
  </div>
);

const CelebrationBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {Array.from({ length: 10 }).map((_, i) => (
      <Star
        key={i}
        className="absolute w-3 h-3 text-yellow-400 fill-yellow-400 animate-star-burst"
        style={{
          left: `${Math.random() * 100}%`,
          top: `${Math.random() * 100}%`,
          animationDelay: `${i * 0.08}s`,
        }}
      />
    ))}
  </div>
);

const WeddingBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {Array.from({ length: 6 }).map((_, i) => (
      <Flower2
        key={i}
        className="absolute w-4 h-4 text-pink-300 animate-flower-burst"
        style={{
          left: `${Math.random() * 100}%`,
          top: `${Math.random() * 100}%`,
          animationDelay: `${i * 0.15}s`,
        }}
      />
    ))}
  </div>
);

const ValentineBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {Array.from({ length: 8 }).map((_, i) => (
      <div key={i}>
        <Heart
          className="absolute w-3 h-3 text-pink-500 fill-pink-500 animate-heart-burst"
          style={{
            left: `${Math.random() * 100}%`,
            top: `${Math.random() * 100}%`,
            animationDelay: `${i * 0.1}s`,
          }}
        />
        {i % 2 === 0 && (
          <div
            className="absolute w-1 h-1 bg-pink-300 rounded-full animate-sparkle-burst"
            style={{
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
              animationDelay: `${i * 0.05}s`,
            }}
          />
        )}
      </div>
    ))}
  </div>
);

const CongratsBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {Array.from({ length: 8 }).map((_, i) => (
      <div key={i}>
        <Award
          className="absolute w-4 h-4 text-yellow-500 animate-award-burst"
          style={{
            left: `${Math.random() * 100}%`,
            top: `${Math.random() * 100}%`,
            animationDelay: `${i * 0.12}s`,
          }}
        />
        <div
          className="absolute w-1 h-1 bg-yellow-400 rounded-full animate-gold-sparkle"
          style={{
            left: `${Math.random() * 100}%`,
            top: `${Math.random() * 100}%`,
            animationDelay: `${i * 0.08}s`,
          }}
        />
      </div>
    ))}
  </div>
);

const AppreciationBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {Array.from({ length: 6 }).map((_, i) => (
      <Gift
        key={i}
        className="absolute w-3 h-3 text-green-500 animate-gift-burst"
        style={{
          left: `${Math.random() * 100}%`,
          top: `${Math.random() * 100}%`,
          animationDelay: `${i * 0.15}s`,
        }}
      />
    ))}
  </div>
);

const FestivalBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {Array.from({ length: 8 }).map((_, i) => (
      <Music
        key={i}
        className="absolute w-3 h-3 text-purple-500 animate-music-burst"
        style={{
          left: `${Math.random() * 100}%`,
          top: `${Math.random() * 100}%`,
          animationDelay: `${i * 0.1}s`,
        }}
      />
    ))}
  </div>
);

const EventBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {Array.from({ length: 6 }).map((_, i) => (
      <Calendar
        key={i}
        className="absolute w-3 h-3 text-blue-500 animate-calendar-burst"
        style={{
          left: `${Math.random() * 100}%`,
          top: `${Math.random() * 100}%`,
          animationDelay: `${i * 0.12}s`,
        }}
      />
    ))}
  </div>
);

const DefaultBurst = () => (
  <div className="absolute inset-0 animate-celebration-burst">
    {Array.from({ length: 10 }).map((_, i) => (
      <Sparkles
        key={i}
        className="absolute w-3 h-3 text-yellow-400 animate-sparkle-burst"
        style={{
          left: `${Math.random() * 100}%`,
          top: `${Math.random() * 100}%`,
          animationDelay: `${i * 0.08}s`,
        }}
      />
    ))}
  </div>
);