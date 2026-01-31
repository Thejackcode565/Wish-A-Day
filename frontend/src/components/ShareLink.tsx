import { useState } from "react";
import { Check, Copy, Share2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface ShareLinkProps {
  url: string;
}

export function ShareLink({ url }: ShareLinkProps) {
  const [copied, setCopied] = useState(false);

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error("Failed to copy:", err);
    }
  };

  const handleShare = async () => {
    if (navigator.share) {
      try {
        await navigator.share({
          title: "A special wish for you! 💫",
          text: "Someone made a wish for you",
          url: url,
        });
      } catch (err) {
        if ((err as Error).name !== "AbortError") {
          console.error("Failed to share:", err);
        }
      }
    } else {
      copyToClipboard();
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 p-3 bg-secondary rounded-xl">
        <div className="flex-1 truncate text-sm font-medium text-foreground">
          {url}
        </div>
        <Button
          size="sm"
          variant={copied ? "soft" : "default"}
          onClick={copyToClipboard}
          className="shrink-0"
        >
          {copied ? (
            <>
              <Check className="w-4 h-4" />
              Copied!
            </>
          ) : (
            <>
              <Copy className="w-4 h-4" />
              Copy
            </>
          )}
        </Button>
      </div>

      {"share" in navigator && (
        <Button
          variant="hero"
          size="lg"
          onClick={handleShare}
          className="w-full"
        >
          <Share2 className="w-5 h-5" />
          Share this wish
        </Button>
      )}

      <p className="text-center text-muted-foreground text-sm">
        Share this link with your loved one 💫
      </p>
    </div>
  );
}
