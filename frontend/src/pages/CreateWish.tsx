import { useState, useEffect } from "react";
import { useNavigate, Link } from "react-router-dom";
import { ArrowLeft, Sparkles, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { ImageUploader } from "@/components/ImageUploader";
import { ExpirySelector, ExpiryType } from "@/components/ExpirySelector";
import { ThemeSelector, WishTheme } from "@/components/ThemeSelector";
import { CelebrationItems, CelebrationItem } from "@/components/CelebrationItems";
import { ShareLink } from "@/components/ShareLink";
import { WishCard } from "@/components/WishCard";
import { createWish, uploadImage } from "@/services/api";
import { useToast } from "@/hooks/use-toast";

const CreateWish = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  
  // Form state
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [theme, setTheme] = useState<WishTheme>("default");
  const [expiryType, setExpiryType] = useState<ExpiryType>("time");
  const [expiresAt, setExpiresAt] = useState<Date>();
  const [maxViews, setMaxViews] = useState<number>();
  const [images, setImages] = useState<File[]>([]);
  const [celebrationItems, setCelebrationItems] = useState<CelebrationItem[]>([]);
  
  // UI state
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [createdWishUrl, setCreatedWishUrl] = useState<string | null>(null);
  const [showPreview, setShowPreview] = useState(false);

  // Set default expiry date (7 days from now)
  useEffect(() => {
    if (!expiresAt) {
      const defaultDate = new Date();
      defaultDate.setDate(defaultDate.getDate() + 7);
      setExpiresAt(defaultDate);
    }
  }, [expiresAt]);

  const isValid = message.trim().length > 0 && (
    (expiryType === "time" && expiresAt) || 
    (expiryType === "views" && maxViews && maxViews > 0)
  );

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!isValid || isSubmitting) return;

    setIsSubmitting(true);

    try {
      // Create wish
      const payload = {
        title: title.trim() || undefined,
        message: message.trim(),
        theme,
        expires_at: expiryType === "time" && expiresAt ? expiresAt.toISOString() : undefined,
        max_views: expiryType === "views" ? maxViews : undefined,
      };

      const result = await createWish(payload);

      // Upload images
      for (const image of images) {
        await uploadImage(result.slug, image);
      }

      setCreatedWishUrl(result.public_url);
      
      toast({
        title: "Wish created! 🎉",
        description: "Your wish is ready to share",
      });
    } catch (error) {
      toast({
        title: "Something went wrong",
        description: "Failed to create wish. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  // Show success state
  if (createdWishUrl) {
    return (
      <div className="min-h-screen bg-background py-12">
        <div className="container px-4 max-w-xl mx-auto">
          <div className="text-center mb-8 animate-slide-up">
            <div className="w-20 h-20 mx-auto mb-6 rounded-full gradient-button flex items-center justify-center shadow-glow">
              <Sparkles className="w-10 h-10 text-primary-foreground" />
            </div>
            <h1 className="text-3xl font-display font-bold text-foreground mb-2">
              Your wish is ready! 🎉
            </h1>
            <p className="text-muted-foreground">
              Share this link to spread the joy
            </p>
          </div>

          <div className="bg-card rounded-2xl p-6 shadow-card animate-slide-up" style={{ animationDelay: "0.1s" }}>
            <ShareLink url={createdWishUrl} />
          </div>

          <div className="mt-8 text-center animate-fade-in" style={{ animationDelay: "0.2s" }}>
            <Button asChild variant="ghost">
              <Link to="/create">Create another wish</Link>
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-background/80 backdrop-blur-sm border-b border-border">
        <div className="container px-4 py-4 flex items-center justify-between">
          <Button asChild variant="ghost" size="sm">
            <Link to="/">
              <ArrowLeft className="w-4 h-4" />
              Back
            </Link>
          </Button>
          <h1 className="text-lg font-display font-semibold">Create Wish</h1>
          <Button
            variant="soft"
            size="sm"
            onClick={() => setShowPreview(!showPreview)}
          >
            {showPreview ? "Edit" : "Preview"}
          </Button>
        </div>
      </header>

      <div className="container px-4 py-8">
        <div className="max-w-2xl mx-auto">
          {showPreview ? (
            <div className="animate-fade-in">
              <WishCard
                title={title || undefined}
                message={message || "Your message will appear here..."}
                theme={theme}
                images={images.map((f) => URL.createObjectURL(f))}
                celebrationItems={celebrationItems}
              />
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-8">
              {/* Title */}
              <div className="space-y-2 animate-slide-up">
                <Label htmlFor="title">Title (optional)</Label>
                <Input
                  id="title"
                  placeholder="Happy Birthday! 🎂"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  maxLength={100}
                />
              </div>

              {/* Message */}
              <div className="space-y-2 animate-slide-up" style={{ animationDelay: "0.05s" }}>
                <Label htmlFor="message">
                  Message <span className="text-destructive">*</span>
                </Label>
                <Textarea
                  id="message"
                  placeholder="Write your heartfelt message here..."
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  rows={5}
                  maxLength={2000}
                  className="resize-none"
                />
                <p className="text-xs text-muted-foreground text-right">
                  {message.length} / 2000
                </p>
              </div>

              {/* Theme */}
              <div className="space-y-3 animate-slide-up" style={{ animationDelay: "0.1s" }}>
                <Label>Theme</Label>
                <ThemeSelector value={theme} onChange={setTheme} />
              </div>

              {/* Celebration Items */}
              <div className="space-y-3 animate-slide-up" style={{ animationDelay: "0.15s" }}>
                <Label>Celebration Items (optional)</Label>
                <CelebrationItems items={celebrationItems} onChange={setCelebrationItems} />
              </div>

              {/* Images */}
              <div className="space-y-3 animate-slide-up" style={{ animationDelay: "0.2s" }}>
                <Label>Images (optional)</Label>
                <ImageUploader images={images} onImagesChange={setImages} />
              </div>

              {/* Expiry */}
              <div className="space-y-3 animate-slide-up" style={{ animationDelay: "0.25s" }}>
                <Label>Expiry</Label>
                <ExpirySelector
                  expiryType={expiryType}
                  onExpiryTypeChange={setExpiryType}
                  expiresAt={expiresAt}
                  onExpiresAtChange={setExpiresAt}
                  maxViews={maxViews}
                  onMaxViewsChange={setMaxViews}
                />
              </div>

              {/* Submit */}
              <div className="pt-4 animate-slide-up" style={{ animationDelay: "0.3s" }}>
                <Button
                  type="submit"
                  variant="hero"
                  size="xl"
                  className="w-full"
                  disabled={!isValid || isSubmitting}
                >
                  {isSubmitting ? (
                    <>
                      <Loader2 className="w-5 h-5 animate-spin" />
                      Creating...
                    </>
                  ) : (
                    <>
                      <Sparkles className="w-5 h-5" />
                      Create Wish
                    </>
                  )}
                </Button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};

export default CreateWish;
