import { Link } from "react-router-dom";
import { Ghost, Home } from "lucide-react";
import { Button } from "@/components/ui/button";

const NotFound = () => {
  return (
    <div className="min-h-screen flex items-center justify-center bg-background">
      <div className="text-center px-4 max-w-md mx-auto">
        <div className="w-24 h-24 mx-auto mb-8 rounded-full bg-secondary flex items-center justify-center animate-float">
          <Ghost className="w-12 h-12 text-muted-foreground" />
        </div>
        <h1 className="text-4xl font-display font-bold text-foreground mb-4">
          Nothing to see here 👀
        </h1>
        <p className="text-muted-foreground mb-8">
          This page seems to have wandered off. Let's get you back home.
        </p>
        <Button asChild variant="hero" size="lg">
          <Link to="/">
            <Home className="w-5 h-5" />
            Go Home
          </Link>
        </Button>
      </div>
    </div>
  );
};

export default NotFound;
