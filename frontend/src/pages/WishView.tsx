import { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { Loader2, Sparkles, HeartCrack, Ghost } from "lucide-react";
import { Button } from "@/components/ui/button";
import { WishCard } from "@/components/WishCard";
import { WishTheme } from "@/components/ThemeSelector";
import { getWish, Wish } from "@/services/api";

type WishState = 
  | { status: "loading" }
  | { status: "success"; wish: Wish }
  | { status: "not_found" }
  | { status: "expired" }
  | { status: "error" };

const WishView = () => {
  const { slug } = useParams<{ slug: string }>();
  const [state, setState] = useState<WishState>({ status: "loading" });

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
        } else {
          setState({ status: "error" });
        }
      } catch (error) {
        setState({ status: "error" });
      }
    };

    fetchWish();
  }, [slug]);

  // Loading state
  if (state.status === "loading") {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="text-center">
          <div className="w-16 h-16 mx-auto mb-4 rounded-full gradient-button flex items-center justify-center animate-pulse">
            <Sparkles className="w-8 h-8 text-primary-foreground" />
          </div>
          <p className="text-muted-foreground">Loading your wish...</p>
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

  // Success state
  const { wish } = state;

  return (
    <div className={`min-h-screen theme-${wish.theme} relative`}>
      {/* Theme background */}
      <div className="absolute inset-0 theme-gradient opacity-5" />
      
      <div className="relative z-10 min-h-screen flex flex-col">
        <div className="flex-1 flex items-center justify-center py-12 px-4">
          <div className="w-full max-w-2xl animate-slide-up">
            <WishCard
              title={wish.title}
              message={wish.message}
              theme={wish.theme as WishTheme}
              images={wish.images}
              remainingViews={wish.remaining_views}
            />
          </div>
        </div>

        {/* Footer */}
        <footer className="py-6 text-center">
          <Link
            to="/create"
            className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-primary transition-colors"
          >
            <Sparkles className="w-4 h-4" />
            Create your own wish
          </Link>
        </footer>
      </div>
    </div>
  );
};

export default WishView;
