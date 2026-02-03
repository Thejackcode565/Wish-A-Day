import { useEffect, useState, useCallback } from "react";
import { CelebrationItem } from "../CelebrationItems";
import { 
  Candy, Cake, Gift, PartyPopper, Sparkles 
} from "lucide-react";

interface CelebrationEffectsProps {
  items: CelebrationItem[];
  isActive: boolean;
  onComplete?: () => void;
}

interface AnimatedItem {
  id: string;
  type: CelebrationItem["type"];
  x: number;
  y: number;
  delay: number;
  color: string;
  size: number;
  rotation: number;
}

// Generate animated items based on celebration items
const generateAnimatedItems = (items: CelebrationItem[]): AnimatedItem[] => {
  const animatedItems: AnimatedItem[] = [];
  
  items.forEach((item) => {
    const count = Math.min(item.quantity * 3, 15); // Limit for performance
    for (let i = 0; i < count; i++) {
      animatedItems.push({
        id: `${item.id}-${i}`,
        type: item.type,
        x: Math.random() * 100,
        y: Math.random() * 100,
        delay: Math.random() * 2,
        color: item.color || "#FFD700",
        size: 16 + Math.random() * 16,
        rotation: Math.random() * 360,
      });
    }
  });
  
  return animatedItems;
};

// Chocolate animation - smooth slide-in
const ChocolateEffect = ({ item }: { item: AnimatedItem }) => (
  <div
    className="absolute animate-chocolate-slide"
    style={{
      left: `${item.x}%`,
      top: `${item.y}%`,
      animationDelay: `${item.delay}s`,
    }}
  >
    <div 
      className="chocolate-wrapper"
      style={{ 
        backgroundColor: item.color,
        width: item.size * 1.5,
        height: item.size,
        borderRadius: item.size * 0.2,
      }}
    >
      <Candy 
        className="text-white/80" 
        style={{ width: item.size * 0.8, height: item.size * 0.8 }}
      />
    </div>
  </div>
);

// Cake animation - gentle bounce with candle glow
const CakeEffect = ({ item }: { item: AnimatedItem }) => (
  <div
    className="absolute animate-cake-bounce"
    style={{
      left: `${item.x}%`,
      bottom: `${10 + item.y * 0.3}%`,
      animationDelay: `${item.delay}s`,
    }}
  >
    <div className="relative">
      <div 
        className="cake-base"
        style={{ 
          backgroundColor: item.color,
          width: item.size * 2,
          height: item.size * 1.5,
        }}
      >
        {/* Frosting */}
        <div className="cake-frosting" />
        {/* Candle */}
        <div className="cake-candle">
          <div className="candle-flame animate-flame-flicker" />
        </div>
      </div>
      <Cake 
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-white/60"
        style={{ width: item.size, height: item.size }}
      />
    </div>
  </div>
);

// Balloon animation - floating upward with sway
const BalloonEffect = ({ item }: { item: AnimatedItem }) => (
  <div
    className="absolute animate-balloon-rise"
    style={{
      left: `${item.x}%`,
      animationDelay: `${item.delay}s`,
      animationDuration: `${4 + item.delay}s`,
    }}
  >
    <div className="balloon-container">
      <div 
        className="balloon"
        style={{ 
          backgroundColor: item.color,
          width: item.size * 1.8,
          height: item.size * 2.2,
        }}
      >
        <div className="balloon-shine" />
      </div>
      <div 
        className="balloon-string"
        style={{ height: item.size * 1.5 }}
      />
    </div>
  </div>
);

// Popper animation - burst effect on trigger
const PopperEffect = ({ item }: { item: AnimatedItem }) => {
  const [popped, setPopped] = useState(false);
  
  useEffect(() => {
    const timer = setTimeout(() => setPopped(true), item.delay * 1000 + 500);
    return () => clearTimeout(timer);
  }, [item.delay]);
  
  return (
    <div
      className="absolute"
      style={{
        left: `${item.x}%`,
        top: `${15 + item.y * 0.5}%`,
      }}
    >
      <div className={`popper-container ${popped ? 'popped' : ''}`}>
        <PartyPopper 
          className="animate-popper-shake"
          style={{ 
            width: item.size * 1.5, 
            height: item.size * 1.5,
            color: item.color,
          }}
        />
        {popped && (
          <div className="popper-burst">
            {Array.from({ length: 12 }).map((_, i) => (
              <div 
                key={i}
                className="burst-particle animate-burst-fly"
                style={{
                  backgroundColor: item.color,
                  transform: `rotate(${i * 30}deg)`,
                  animationDelay: `${i * 0.05}s`,
                }}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

// Gift animation - box opening with glow
const GiftEffect = ({ item }: { item: AnimatedItem }) => {
  const [opened, setOpened] = useState(false);
  
  useEffect(() => {
    const timer = setTimeout(() => setOpened(true), item.delay * 1000 + 800);
    return () => clearTimeout(timer);
  }, [item.delay]);
  
  return (
    <div
      className="absolute animate-gift-appear"
      style={{
        left: `${item.x}%`,
        bottom: `${5 + item.y * 0.4}%`,
        animationDelay: `${item.delay}s`,
      }}
    >
      <div className={`gift-box ${opened ? 'opened' : ''}`}>
        <div 
          className="gift-lid"
          style={{ backgroundColor: item.color }}
        />
        <div 
          className="gift-base"
          style={{ 
            backgroundColor: item.color,
            width: item.size * 2,
            height: item.size * 1.5,
          }}
        >
          <div className="gift-ribbon" />
        </div>
        <Gift 
          className="gift-icon text-white/70"
          style={{ width: item.size, height: item.size }}
        />
        {opened && (
          <div className="gift-glow animate-gift-glow">
            <Sparkles className="text-amber-400" style={{ width: item.size, height: item.size }} />
          </div>
        )}
      </div>
    </div>
  );
};

// Confetti animation - full-screen burst with gravity
const ConfettiEffect = ({ item }: { item: AnimatedItem }) => {
  const colors = [item.color, "#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3", "#F38181"];
  
  return (
    <>
      {Array.from({ length: 8 }).map((_, i) => (
        <div
          key={`${item.id}-confetti-${i}`}
          className="absolute animate-confetti-gravity"
          style={{
            left: `${item.x + (i - 4) * 5}%`,
            animationDelay: `${item.delay + i * 0.1}s`,
            animationDuration: `${3 + Math.random() * 2}s`,
          }}
        >
          <div 
            className="confetti-particle"
            style={{
              backgroundColor: colors[i % colors.length],
              width: item.size * 0.4,
              height: item.size * 0.6,
              transform: `rotate(${item.rotation + i * 45}deg)`,
            }}
          />
        </div>
      ))}
    </>
  );
};

// Main celebration effects component
export function CelebrationEffects({ items, isActive, onComplete }: CelebrationEffectsProps) {
  const [animatedItems, setAnimatedItems] = useState<AnimatedItem[]>([]);
  const [showEffects, setShowEffects] = useState(false);

  useEffect(() => {
    if (isActive && items.length > 0) {
      setAnimatedItems(generateAnimatedItems(items));
      // Slight delay before showing effects for smooth transition
      const timer = setTimeout(() => setShowEffects(true), 300);
      return () => clearTimeout(timer);
    }
  }, [isActive, items]);

  useEffect(() => {
    if (showEffects && onComplete) {
      // Call onComplete after animations finish
      const timer = setTimeout(onComplete, 5000);
      return () => clearTimeout(timer);
    }
  }, [showEffects, onComplete]);

  if (!isActive || !showEffects || animatedItems.length === 0) return null;

  const renderEffect = (item: AnimatedItem) => {
    switch (item.type) {
      case "chocolates":
        return <ChocolateEffect key={item.id} item={item} />;
      case "cake":
        return <CakeEffect key={item.id} item={item} />;
      case "balloons":
        return <BalloonEffect key={item.id} item={item} />;
      case "poppers":
        return <PopperEffect key={item.id} item={item} />;
      case "gifts":
        return <GiftEffect key={item.id} item={item} />;
      case "confetti":
        return <ConfettiEffect key={item.id} item={item} />;
      default:
        return null;
    }
  };

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none z-10">
      {animatedItems.map(renderEffect)}
    </div>
  );
}

export default CelebrationEffects;
