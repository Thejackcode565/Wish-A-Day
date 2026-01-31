import { Link } from "react-router-dom";
import { Sparkles, Heart, Gift, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { WishCard } from "@/components/WishCard";
import heroBg from "@/assets/hero-bg.jpg";

const Home = () => {
  return (
    <div className="min-h-screen">
      {/* Hero Section */}
      <section className="relative min-h-[90vh] flex items-center justify-center overflow-hidden">
        {/* Background image */}
        <div
          className="absolute inset-0 bg-cover bg-center"
          style={{ backgroundImage: `url(${heroBg})` }}
        />
        <div className="absolute inset-0 bg-gradient-to-b from-background/20 via-background/60 to-background" />
        
        {/* Floating decorations */}
        <div className="absolute inset-0 pointer-events-none overflow-hidden">
          <Heart 
            className="absolute top-[20%] left-[10%] w-8 h-8 text-primary/30 animate-float" 
            style={{ animationDelay: "0s" }}
          />
          <Sparkles 
            className="absolute top-[30%] right-[15%] w-6 h-6 text-accent/40 animate-float" 
            style={{ animationDelay: "0.5s" }}
          />
          <Gift 
            className="absolute bottom-[30%] left-[20%] w-10 h-10 text-primary/20 animate-float" 
            style={{ animationDelay: "1s" }}
          />
          <Heart 
            className="absolute bottom-[25%] right-[10%] w-6 h-6 text-primary/25 animate-float" 
            style={{ animationDelay: "1.5s" }}
          />
        </div>

        <div className="relative z-10 container px-4 py-20">
          <div className="max-w-3xl mx-auto text-center">
            {/* Badge */}
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 text-primary mb-8 animate-fade-in">
              <Sparkles className="w-4 h-4" />
              <span className="text-sm font-medium">Make someone's day special</span>
            </div>

            {/* Heading */}
            <h1 className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-display font-bold text-foreground mb-6 animate-slide-up">
              Send wishes that{" "}
              <span className="text-primary">sparkle</span>
            </h1>

            {/* Subheading */}
            <p 
              className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto mb-10 animate-slide-up"
              style={{ animationDelay: "0.1s" }}
            >
              Create beautiful, personalized wishes for your loved ones. 
              Add images, choose themes, and share moments that matter.
            </p>

            {/* CTA */}
            <div 
              className="flex flex-col sm:flex-row gap-4 justify-center items-center animate-slide-up"
              style={{ animationDelay: "0.2s" }}
            >
              <Button asChild variant="hero" size="xl">
                <Link to="/create">
                  Create Your Wish
                  <ArrowRight className="w-5 h-5" />
                </Link>
              </Button>
            </div>
          </div>
        </div>
      </section>

      {/* Preview Section */}
      <section className="py-20 bg-secondary/30">
        <div className="container px-4">
          <div className="max-w-2xl mx-auto">
            <div className="text-center mb-12">
              <h2 className="text-3xl md:text-4xl font-display font-bold text-foreground mb-4">
                See it in action
              </h2>
              <p className="text-muted-foreground">
                Here's an example of what your wish could look like
              </p>
            </div>

            <WishCard
              title="Happy Birthday! 🎂"
              message="Wishing you the most amazing day filled with joy, laughter, and all the love in the world. May this year bring you endless happiness and make all your dreams come true!"
              theme="birthday"
              className="transform hover:scale-[1.02] transition-transform duration-300"
            />
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20">
        <div className="container px-4">
          <div className="max-w-4xl mx-auto">
            <div className="text-center mb-16">
              <h2 className="text-3xl md:text-4xl font-display font-bold text-foreground mb-4">
                Why Wishaday?
              </h2>
            </div>

            <div className="grid md:grid-cols-3 gap-8">
              {[
                {
                  icon: Heart,
                  title: "Personal Touch",
                  description: "Add your own message and up to 5 photos to make it truly special",
                },
                {
                  icon: Sparkles,
                  title: "Beautiful Themes",
                  description: "Choose from multiple themes to match the occasion perfectly",
                },
                {
                  icon: Gift,
                  title: "Share Easily",
                  description: "Get a unique link to share via any messaging app or social media",
                },
              ].map((feature, index) => {
                const Icon = feature.icon;
                return (
                  <div
                    key={index}
                    className="text-center p-6 rounded-2xl bg-card shadow-soft hover:shadow-card transition-shadow duration-300"
                  >
                    <div className="w-14 h-14 mx-auto mb-4 rounded-xl gradient-button flex items-center justify-center shadow-soft">
                      <Icon className="w-7 h-7 text-primary-foreground" />
                    </div>
                    <h3 className="text-lg font-semibold text-foreground mb-2">
                      {feature.title}
                    </h3>
                    <p className="text-muted-foreground text-sm">
                      {feature.description}
                    </p>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </section>

      {/* Footer CTA */}
      <section className="py-20 relative overflow-hidden">
        <div className="absolute inset-0 gradient-hero opacity-10" />
        <div className="container px-4 relative z-10">
          <div className="max-w-2xl mx-auto text-center">
            <h2 className="text-3xl md:text-4xl font-display font-bold text-foreground mb-6">
              Ready to make someone smile?
            </h2>
            <Button asChild variant="hero" size="xl">
              <Link to="/create">
                Create Your Wish
                <ArrowRight className="w-5 h-5" />
              </Link>
            </Button>
          </div>
        </div>
      </section>

      {/* Simple Footer */}
      <footer className="py-8 border-t border-border">
        <div className="container px-4 text-center">
          <p className="text-sm text-muted-foreground">
            Made with 💖 by Wishaday
          </p>
        </div>
      </footer>
    </div>
  );
};

export default Home;
