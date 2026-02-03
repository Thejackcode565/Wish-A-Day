import { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { Loader2, Sparkles, HeartCrack, Ghost } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CelebrationItem } from "@/components/CelebrationItems";
import { WishCard } from "@/components/WishCard";
import { WishTheme } from "@/components/ThemeSelector";
import { GiftBoxOpener } from "@/components/animations";
import { getWish, Wish } from "@/services/api";
import { cn } from "@/lib/utils";

type WishState = 
  | { status: "loading" }
  | { status: "success"; wish: Wish }
  | { status: "not_found" }
  | { status: "expired" }
  | { status: "error" };

// Transform API celebration items to CelebrationItem format
const transformCelebrationItems = (items?: any[]): CelebrationItem[] => {
  if (!items || !Array.isArray(items)) return [];
  return items.map((item, index) => ({
    id: `item-${index}`,
    type: item.type as CelebrationItem["type"],
    quantity: item.quantity || 1,
    color: item.color,
    message: item.message,
  }));
};

const WishView = () => {
  const { slug } = useParams<{ slug: string }>();
  const [state, setState] = useState<WishState>({ status: "loading" });
  const [pageLoaded, setPageLoaded] = useState(false);
  const [showGiftBox, setShowGiftBox] = useState(false);
  const [giftBoxComplete, setGiftBoxComplete] = useState(false);

  useEffect(() => {
    if (!slug) {
      setState({ status: "not_found" });
      return;
    }

    const fetchWish = async () => {
      try {
        const result = await getWish(slug);
        
        if (result.status === 404) {
          setState({ status: "not_found" });
        } else if (result.status === 410) {
          setState({ status: "expired" });
        } else if (result.data) {
          setState({ status: "success", wish: result.data });
          
          // Start gift box animation after wish is loaded
          setTimeout(() => {
            setShowGiftBox(true);
          }, 500);
        } else {
          setState({ status: "error" });
        }
      } catch (error) {
        setState({ status: "error" });
      }
    };

    fetchWish();
  }, [slug]);

  // Handle gift box opening completion
  const handleGiftBoxComplete = () => {
    setGiftBoxComplete(true);
    setTimeout(() => setPageLoaded(true), 200);
  };

  // Enhanced loading state with theme preview
  if (state.status === "loading") {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background relative overflow-hidden">
        {/* Animated background */}
        <div className="absolute inset-0 bg-gradient-to-br from-primary/10 via-accent/5 to-primary/10 animate-gradient-shift" />
        
        {/* Loading sparkles */}
        <div className="absolute inset-0">
          {Array.from({ length: 12 }).map((_, i) => (
            <div
              key={i}
              className="absolute animate-loading-sparkle"
              style={{
                left: `${10 + i * 8}%`,
                top: `${20 + (i % 3) * 20}%`,
                animationDelay: `${i * 0.2}s`,
              }}
            >
              <Sparkles className="w-4 h-4 text-primary/30" />
            </div>
          ))}
        </div>
        
        <div className="text-center relative z-10">
          <div className="w-20 h-20 mx-auto mb-6 rounded-full gradient-button flex items-center justify-center animate-loading-pulse">
            <Sparkles className="w-10 h-10 text-primary-foreground animate-spin-slow" />
          </div>
          <p className="text-lg text-muted-foreground animate-loading-text">
            Preparing your magical wish...
          </p>
          <div className="mt-4 flex justify-center gap-1">
            {Array.from({ length: 3 }).map((_, i) => (
              <div
                key={i}
                className="w-2 h-2 rounded-full bg-primary animate-loading-dots"
                style={{ animationDelay: `${i * 0.2}s` }}
              />
            ))}
          </div>
        </div>
      </div>
    );
  }

  // Not found state
  if (state.status === "not_found") {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="text-center px-4 max-w-md mx-auto">
          <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-secondary flex items-center justify-center">
            <Ghost className="w-10 h-10 text-muted-foreground" />
          </div>
          <h1 className="text-2xl font-display font-bold text-foreground mb-3">
            This wish does not exist
          </h1>
          <p className="text-muted-foreground mb-8">
            The link might be incorrect, or the wish may have been removed.
          </p>
          <Button asChild variant="hero">
            <Link to="/">Go Home</Link>
          </Button>
        </div>
      </div>
    );
  }

  // Expired state
  if (state.status === "expired") {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="text-center px-4 max-w-md mx-auto">
          <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-accent/20 flex items-center justify-center">
            <HeartCrack className="w-10 h-10 text-accent" />
          </div>
          <h1 className="text-2xl font-display font-bold text-foreground mb-3">
            This wish has expired 💫
          </h1>
          <p className="text-muted-foreground mb-8">
            Beautiful moments sometimes fade away, but the memories last forever.
          </p>
          <Button asChild variant="hero">
            <Link to="/create">Create a New Wish</Link>
          </Button>
        </div>
      </div>
    );
  }

  // Error state
  if (state.status === "error") {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="text-center px-4 max-w-md mx-auto">
          <h1 className="text-2xl font-display font-bold text-foreground mb-3">
            Something went wrong
          </h1>
          <p className="text-muted-foreground mb-8">
            We couldn't load this wish. Please try again.
          </p>
          <Button onClick={() => window.location.reload()} variant="hero">
            Try Again
          </Button>
        </div>
      </div>
    );
  }

  // Success state with enhanced animations and gift box opener
  const { wish } = state;

  return (
    <div className={`min-h-screen theme-${wish.theme} relative overflow-hidden`}>
      {/* Gift Box Opener - shows first */}
      {showGiftBox && !giftBoxComplete && (
        <GiftBoxOpener
          theme={wish.theme as WishTheme}
          onOpenComplete={handleGiftBoxComplete}
          isActive={showGiftBox}
        />
      )}

      {/* Enhanced theme background with animation */}
      <div className="absolute inset-0 theme-gradient opacity-8 animate-background-pulse" />
      
      {/* Ambient theme particles */}
      <div className="absolute inset-0 pointer-events-none">
        {Array.from({ length: 15 }).map((_, i) => (
          <div
            key={i}
            className="absolute animate-ambient-float"
            style={{
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
              animationDelay: `${i * 0.3}s`,
              animationDuration: `${8 + Math.random() * 4}s`,
            }}
          >
            <div 
              className="w-2 h-2 rounded-full bg-primary/20"
              style={{ 
                boxShadow: `0 0 ${4 + Math.random() * 8}px hsl(var(--primary) / 0.3)` 
              }}
            />
          </div>
        ))}
      </div>
      
      <div className="relative z-10 min-h-screen flex flex-col">
        <div className="flex-1 flex items-center justify-center py-12 px-4">
          <div className={cn(
            "w-full max-w-2xl transition-all duration-1000",
            pageLoaded && giftBoxComplete ? "animate-wish-entrance" : "opacity-0 scale-90 translate-y-8"
          )}>
            {giftBoxComplete && (
              <WishCard
                title={wish.title}
                message={wish.message}
                theme={wish.theme as WishTheme}
                images={wish.images}
                celebrationItems={transformCelebrationItems(wish.celebration_items)}
                remainingViews={wish.remaining_views}
                senderName={wish.sender_name}
                senderMessage={wish.sender_message}
              />
            )}
          </div>
        </div>

        {/* Enhanced footer with animation */}
        <footer className={cn(
          "py-6 text-center transition-all duration-700 delay-1000",
          pageLoaded && giftBoxComplete ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"
        )}>
          <Link
            to="/create"
            className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-primary transition-all duration-300 hover:scale-105"
          >
            <Sparkles className="w-4 h-4 animate-sparkle" />
            Create your own wish
          </Link>
        </footer>
      </div>
    </div>
  );
};

export default WishView;
