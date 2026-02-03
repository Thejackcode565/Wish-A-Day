import { useEffect, useState, useMemo } from "react";
import { WishTheme } from "../ThemeSelector";
import { 
  Heart, Star, Sparkles, Flower2, Music, 
  Gift, Award, PartyPopper, Calendar, Candy
} from "lucide-react";

interface ThemeAnimationsProps {
  theme: WishTheme;
  isActive: boolean;
}

interface FloatingElement {
  id: number;
  x: number;
  delay: number;
  duration: number;
  size: number;
  opacity: number;
}

// Generate random floating elements
const generateElements = (count: number): FloatingElement[] => {
  return Array.from({ length: count }, (_, i) => ({
    id: i,
    x: Math.random() * 100,
    delay: Math.random() * 3,
    duration: 4 + Math.random() * 4,
    size: 12 + Math.random() * 20,
    opacity: 0.3 + Math.random() * 0.4,
  }));
};

// Default Theme - Subtle sparkles and soft fades
const DefaultAnimation = ({ elements }: { elements: FloatingElement[] }) => (
  <div className="theme-animation-container">
    {elements.slice(0, 8).map((el) => (
      <div
        key={el.id}
        className="floating-element animate-gentle-float"
        style={{
          left: `${el.x}%`,
          animationDelay: `${el.delay}s`,
          animationDuration: `${el.duration + 2}s`,
        }}
      >
        <Sparkles 
          className="text-primary/30" 
          style={{ width: el.size, height: el.size }}
        />
      </div>
    ))}
  </div>
);

// Birthday Theme - Bouncing balloons, confetti, cake candles
const BirthdayAnimation = ({ elements }: { elements: FloatingElement[] }) => {
  const balloonColors = ["#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3", "#F38181", "#AA96DA"];
  
  return (
    <div className="theme-animation-container">
      {/* Floating balloons */}
      {elements.slice(0, 6).map((el, i) => (
        <div
          key={`balloon-${el.id}`}
          className="floating-element animate-balloon-float"
          style={{
            left: `${el.x}%`,
            animationDelay: `${el.delay}s`,
            animationDuration: `${el.duration}s`,
          }}
        >
          <div className="relative">
            <div 
              className="balloon-shape"
              style={{ 
                backgroundColor: balloonColors[i % balloonColors.length],
                width: el.size * 1.5,
                height: el.size * 1.8,
              }}
            />
            <div 
              className="balloon-string"
              style={{ height: el.size * 0.8 }}
            />
          </div>
        </div>
      ))}
      
      {/* Confetti burst */}
      {elements.slice(6, 20).map((el) => (
        <div
          key={`confetti-${el.id}`}
          className="confetti-piece animate-confetti-burst"
          style={{
            left: `${el.x}%`,
            animationDelay: `${el.delay}s`,
            backgroundColor: balloonColors[el.id % balloonColors.length],
          }}
        />
      ))}
      
      {/* Party poppers */}
      <PartyPopper 
        className="absolute top-[10%] left-[5%] text-accent animate-bounce-pop" 
        style={{ width: 32, height: 32, animationDelay: "0.5s" }}
      />
      <PartyPopper 
        className="absolute top-[15%] right-[8%] text-primary animate-bounce-pop scale-x-[-1]" 
        style={{ width: 28, height: 28, animationDelay: "1s" }}
      />
    </div>
  );
};

// Love Theme - Floating hearts, rose petals, soft glows
const LoveAnimation = ({ elements }: { elements: FloatingElement[] }) => (
  <div className="theme-animation-container">
    {/* Floating hearts */}
    {elements.slice(0, 12).map((el) => (
      <div
        key={`heart-${el.id}`}
        className="floating-element animate-heart-rise"
        style={{
          left: `${el.x}%`,
          animationDelay: `${el.delay}s`,
          animationDuration: `${el.duration + 2}s`,
        }}
      >
        <Heart 
          className="text-primary fill-primary/50"
          style={{ 
            width: el.size, 
            height: el.size,
            opacity: el.opacity,
          }}
        />
      </div>
    ))}
    
    {/* Rose petals */}
    {elements.slice(12, 20).map((el) => (
      <div
        key={`petal-${el.id}`}
        className="floating-element animate-petal-fall"
        style={{
          left: `${el.x}%`,
          animationDelay: `${el.delay + 1}s`,
          animationDuration: `${el.duration + 3}s`,
        }}
      >
        <div 
          className="rose-petal"
          style={{ 
            width: el.size * 0.6, 
            height: el.size * 0.8,
          }}
        />
      </div>
    ))}
    
    {/* Soft glow orbs */}
    <div className="glow-orb glow-orb-1" />
    <div className="glow-orb glow-orb-2" />
  </div>
);

// Celebration Theme - Confetti bursts, fireworks, dynamic motion
const CelebrationAnimation = ({ elements }: { elements: FloatingElement[] }) => {
  const colors = ["#FFD700", "#FF6B6B", "#4ECDC4", "#FF69B4", "#9370DB"];
  
  return (
    <div className="theme-animation-container">
      {/* Star bursts */}
      {elements.slice(0, 10).map((el, i) => (
        <div
          key={`star-${el.id}`}
          className="floating-element animate-star-burst"
          style={{
            left: `${el.x}%`,
            top: `${20 + (i * 8)}%`,
            animationDelay: `${el.delay}s`,
          }}
        >
          <Star 
            className="fill-current"
            style={{ 
              width: el.size, 
              height: el.size,
              color: colors[i % colors.length],
            }}
          />
        </div>
      ))}
      
      {/* Confetti rain */}
      {elements.slice(10, 25).map((el, i) => (
        <div
          key={`confetti-${el.id}`}
          className="confetti-piece animate-confetti-fall"
          style={{
            left: `${el.x}%`,
            animationDelay: `${el.delay * 0.5}s`,
            backgroundColor: colors[i % colors.length],
            transform: `rotate(${el.delay * 45}deg)`,
          }}
        />
      ))}
      
      {/* Firework sparkles */}
      <div className="firework firework-1" />
      <div className="firework firework-2" />
      <div className="firework firework-3" />
    </div>
  );
};

// Wedding Theme - Elegant florals, golden sparkles, flowing ribbons
const WeddingAnimation = ({ elements }: { elements: FloatingElement[] }) => (
  <div className="theme-animation-container">
    {/* Floating flowers */}
    {elements.slice(0, 8).map((el) => (
      <div
        key={`flower-${el.id}`}
        className="floating-element animate-gentle-sway"
        style={{
          left: `${el.x}%`,
          animationDelay: `${el.delay}s`,
          animationDuration: `${el.duration + 4}s`,
        }}
      >
        <Flower2 
          className="text-primary/40"
          style={{ width: el.size * 1.2, height: el.size * 1.2 }}
        />
      </div>
    ))}
    
    {/* Golden sparkles */}
    {elements.slice(8, 16).map((el) => (
      <div
        key={`sparkle-${el.id}`}
        className="floating-element animate-golden-shimmer"
        style={{
          left: `${el.x}%`,
          top: `${el.x * 0.8}%`,
          animationDelay: `${el.delay}s`,
        }}
      >
        <Sparkles 
          className="text-amber-400/60"
          style={{ width: el.size * 0.8, height: el.size * 0.8 }}
        />
      </div>
    ))}
    
    {/* Flowing ribbons */}
    <div className="ribbon ribbon-left" />
    <div className="ribbon ribbon-right" />
  </div>
);

// Valentine Theme - Heart pulses, floating chocolates, romantic sparkles
const ValentineAnimation = ({ elements }: { elements: FloatingElement[] }) => (
  <div className="theme-animation-container">
    {/* Pulsing hearts */}
    {elements.slice(0, 10).map((el) => (
      <div
        key={`heart-${el.id}`}
        className="floating-element animate-heart-pulse"
        style={{
          left: `${el.x}%`,
          top: `${15 + Math.random() * 70}%`,
          animationDelay: `${el.delay * 0.5}s`,
        }}
      >
        <Heart 
          className="text-rose-500 fill-rose-400/70"
          style={{ width: el.size, height: el.size }}
        />
      </div>
    ))}
    
    {/* Floating chocolates */}
    {elements.slice(10, 14).map((el) => (
      <div
        key={`choco-${el.id}`}
        className="floating-element animate-float-gentle"
        style={{
          left: `${el.x}%`,
          animationDelay: `${el.delay}s`,
          animationDuration: `${el.duration + 2}s`,
        }}
      >
        <Candy 
          className="text-amber-800/60"
          style={{ width: el.size * 1.2, height: el.size * 1.2 }}
        />
      </div>
    ))}
    
    {/* Romantic sparkles */}
    <div className="romantic-glow romantic-glow-1" />
    <div className="romantic-glow romantic-glow-2" />
  </div>
);

// Congratulations Theme - Trophy shines, star bursts, celebratory confetti
const CongratsAnimation = ({ elements }: { elements: FloatingElement[] }) => (
  <div className="theme-animation-container">
    {/* Star bursts */}
    {elements.slice(0, 12).map((el) => (
      <div
        key={`star-${el.id}`}
        className="floating-element animate-star-shine"
        style={{
          left: `${el.x}%`,
          top: `${10 + Math.random() * 60}%`,
          animationDelay: `${el.delay}s`,
        }}
      >
        <Star 
          className="text-amber-500 fill-amber-400/50"
          style={{ width: el.size, height: el.size }}
        />
      </div>
    ))}
    
    {/* Trophy shine effect */}
    <Award 
      className="absolute top-[8%] left-[50%] -translate-x-1/2 text-amber-500 animate-trophy-shine"
      style={{ width: 48, height: 48 }}
    />
    
    {/* Gold confetti */}
    {elements.slice(12, 20).map((el) => (
      <div
        key={`gold-${el.id}`}
        className="confetti-piece animate-gold-fall"
        style={{
          left: `${el.x}%`,
          animationDelay: `${el.delay}s`,
          backgroundColor: "#FFD700",
        }}
      />
    ))}
  </div>
);

// Thanks Theme - Gentle sparkles, smooth fade-ins, warm motion
const ThanksAnimation = ({ elements }: { elements: FloatingElement[] }) => (
  <div className="theme-animation-container">
    {/* Gentle floating gifts */}
    {elements.slice(0, 6).map((el) => (
      <div
        key={`gift-${el.id}`}
        className="floating-element animate-gentle-rise"
        style={{
          left: `${el.x}%`,
          animationDelay: `${el.delay}s`,
          animationDuration: `${el.duration + 3}s`,
        }}
      >
        <Gift 
          className="text-teal-500/50"
          style={{ width: el.size * 1.1, height: el.size * 1.1 }}
        />
      </div>
    ))}
    
    {/* Warm sparkles */}
    {elements.slice(6, 14).map((el) => (
      <div
        key={`sparkle-${el.id}`}
        className="floating-element animate-warm-sparkle"
        style={{
          left: `${el.x}%`,
          top: `${20 + Math.random() * 60}%`,
          animationDelay: `${el.delay}s`,
        }}
      >
        <Sparkles 
          className="text-teal-400/40"
          style={{ width: el.size * 0.7, height: el.size * 0.7 }}
        />
      </div>
    ))}
  </div>
);

// Festival Theme - Lights, lanterns, fireworks, colorful patterns
const FestivalAnimation = ({ elements }: { elements: FloatingElement[] }) => {
  const festivalColors = ["#FF6B6B", "#FFE66D", "#4ECDC4", "#AA96DA", "#F38181", "#95E1D3"];
  
  return (
    <div className="theme-animation-container">
      {/* Floating lanterns */}
      {elements.slice(0, 8).map((el, i) => (
        <div
          key={`lantern-${el.id}`}
          className="floating-element animate-lantern-float"
          style={{
            left: `${el.x}%`,
            animationDelay: `${el.delay}s`,
            animationDuration: `${el.duration + 3}s`,
          }}
        >
          <div 
            className="lantern"
            style={{ 
              backgroundColor: festivalColors[i % festivalColors.length],
              width: el.size * 1.2,
              height: el.size * 1.6,
            }}
          >
            <div className="lantern-glow" />
          </div>
        </div>
      ))}
      
      {/* Music notes */}
      {elements.slice(8, 12).map((el) => (
        <div
          key={`music-${el.id}`}
          className="floating-element animate-music-float"
          style={{
            left: `${el.x}%`,
            animationDelay: `${el.delay + 1}s`,
          }}
        >
          <Music 
            className="text-purple-500/50"
            style={{ width: el.size, height: el.size }}
          />
        </div>
      ))}
      
      {/* Festival lights */}
      <div className="festival-lights" />
    </div>
  );
};

// Event Theme - Modern motion graphics, spotlight effects
const EventAnimation = ({ elements }: { elements: FloatingElement[] }) => (
  <div className="theme-animation-container">
    {/* Geometric shapes */}
    {elements.slice(0, 8).map((el) => (
      <div
        key={`shape-${el.id}`}
        className="floating-element animate-geometric-float"
        style={{
          left: `${el.x}%`,
          top: `${15 + Math.random() * 60}%`,
          animationDelay: `${el.delay}s`,
        }}
      >
        <div 
          className="geometric-shape"
          style={{ 
            width: el.size, 
            height: el.size,
            borderColor: `hsl(210, 70%, ${50 + el.id * 3}%)`,
          }}
        />
      </div>
    ))}
    
    {/* Calendar accents */}
    {elements.slice(8, 11).map((el) => (
      <div
        key={`cal-${el.id}`}
        className="floating-element animate-slide-accent"
        style={{
          left: `${el.x}%`,
          animationDelay: `${el.delay}s`,
        }}
      >
        <Calendar 
          className="text-blue-500/40"
          style={{ width: el.size * 1.2, height: el.size * 1.2 }}
        />
      </div>
    ))}
    
    {/* Spotlight effect */}
    <div className="spotlight spotlight-1" />
    <div className="spotlight spotlight-2" />
  </div>
);

// Main component that renders the appropriate theme animation
export function ThemeAnimations({ theme, isActive }: ThemeAnimationsProps) {
  const [mounted, setMounted] = useState(false);
  const elements = useMemo(() => generateElements(25), []);

  useEffect(() => {
    if (isActive) {
      const timer = setTimeout(() => setMounted(true), 100);
      return () => clearTimeout(timer);
    }
  }, [isActive]);

  if (!isActive || !mounted) return null;

  const animations: Record<WishTheme, React.ReactNode> = {
    default: <DefaultAnimation elements={elements} />,
    birthday: <BirthdayAnimation elements={elements} />,
    love: <LoveAnimation elements={elements} />,
    celebration: <CelebrationAnimation elements={elements} />,
    wedding: <WeddingAnimation elements={elements} />,
    valentine: <ValentineAnimation elements={elements} />,
    congratulations: <CongratsAnimation elements={elements} />,
    appreciation: <ThanksAnimation elements={elements} />,
    festival: <FestivalAnimation elements={elements} />,
    event: <EventAnimation elements={elements} />,
  };

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none z-0">
      {animations[theme]}
    </div>
  );
}

export default ThemeAnimations;
