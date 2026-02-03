import { User, MessageCircle } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";

interface SenderInfoProps {
  senderName: string;
  onSenderNameChange: (name: string) => void;
  senderMessage: string;
  onSenderMessageChange: (message: string) => void;
}

export function SenderInfo({
  senderName,
  onSenderNameChange,
  senderMessage,
  onSenderMessageChange,
}: SenderInfoProps) {
  return (
    <div className="space-y-4 p-4 rounded-xl bg-secondary/30 border border-border">
      <div className="flex items-center gap-2 mb-3">
        <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
          <User className="w-4 h-4 text-primary" />
        </div>
        <h3 className="font-medium text-foreground">From You (optional)</h3>
      </div>
      
      <div className="space-y-4">
        {/* Sender Name */}
        <div className="space-y-2">
          <Label htmlFor="sender-name">Your name</Label>
          <Input
            id="sender-name"
            placeholder="Your name"
            value={senderName}
            onChange={(e) => onSenderNameChange(e.target.value)}
            maxLength={100}
          />
        </div>

        {/* Sender Message */}
        <div className="space-y-2">
          <Label htmlFor="sender-message">Personal note</Label>
          <Textarea
            id="sender-message"
            placeholder="A personal note to the recipient (e.g., 'With love from your friend')"
            value={senderMessage}
            onChange={(e) => onSenderMessageChange(e.target.value)}
            rows={2}
            maxLength={200}
            className="resize-none"
          />
          <p className="text-xs text-muted-foreground text-right">
            {senderMessage.length} / 200
          </p>
        </div>
      </div>
    </div>
  );
}