import { cn } from "@/lib/utils";
import { useState } from "react";
import { 
  Candy, Cake, PartyPopper, CircleDot, Gift, Sparkles 
} from "lucide-react";
import { Input } from "@/components/ui/input";

export type CelebrationItem = {
  id: string;
  type: "chocolates" | "cake" | "balloons" | "poppers" | "gifts" | "confetti";
  quantity: number;
  color?: string;
  message?: string;
};

interface CelebrationItemsProps {
  items: CelebrationItem[];
  onChange: (items: CelebrationItem[]) => void;
}

const itemTypes = [
  { 
    type: "chocolates" as const, 
    label: "Chocolates", 
    icon: Candy,
    colors: ["#8B4513", "#D2691E", "#F5F5DC", "#FFD700"]
  },
  { 
    type: "cake" as const, 
    label: "Cake", 
    icon: Cake,
    colors: ["#FF69B4", "#FFD700", "#FFFFFF", "#8B4513"]
  },
  { 
    type: "balloons" as const, 
    label: "Balloons", 
    icon: CircleDot,
    colors: ["#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3", "#F38181", "#AA96DA"]
  },
  { 
    type: "poppers" as const, 
    label: "Poppers", 
    icon: PartyPopper,
    colors: ["#FFD700", "#FF69B4", "#00CED1", "#9370DB"]
  },
  { 
    type: "gifts" as const, 
    label: "Gifts", 
    icon: Gift,
    colors: ["#FF0000", "#0000FF", "#00FF00", "#FFD700"]
  },
  { 
    type: "confetti" as const, 
    label: "Confetti", 
    icon: Sparkles,
    colors: ["#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3"]
  },
];

export function CelebrationItems({ items, onChange }: CelebrationItemsProps) {
  const [expandedItem, setExpandedItem] = useState<string | null>(null);

  const toggleItem = (type: CelebrationItem["type"]) => {
    const existingIndex = items.findIndex(item => item.type === type);
    
    if (existingIndex >= 0) {
      // Remove item
      const newItems = items.filter(item => item.type !== type);
      onChange(newItems);
      if (expandedItem === type) setExpandedItem(null);
    } else {
      // Add item
      const newItem: CelebrationItem = {
        id: `${type}-${Date.now()}`,
        type,
        quantity: 1,
        color: itemTypes.find(t => t.type === type)?.colors[0],
      };
      onChange([...items, newItem]);
      setExpandedItem(type);
    }
  };

  const updateItem = (type: CelebrationItem["type"], updates: Partial<CelebrationItem>) => {
    const newItems = items.map(item => 
      item.type === type ? { ...item, ...updates } : item
    );
    onChange(newItems);
  };

  const getItem = (type: CelebrationItem["type"]) => 
    items.find(item => item.type === type);

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 sm:grid-cols-6 gap-3">
        {itemTypes.map((itemType) => {
          const Icon = itemType.icon;
          const isSelected = items.some(item => item.type === itemType.type);
          const isExpanded = expandedItem === itemType.type;
          
          return (
            <button
              key={itemType.type}
              type="button"
              onClick={() => toggleItem(itemType.type)}
              className={cn(
                "relative flex flex-col items-center gap-2 p-3 rounded-xl border-2 transition-all duration-200",
                isSelected
                  ? "border-primary bg-primary/10 shadow-soft"
                  : "border-border hover:border-primary/50 hover:bg-secondary/50"
              )}
            >
              <div
                className={cn(
                  "w-10 h-10 rounded-full flex items-center justify-center transition-all duration-200",
                  isSelected 
                    ? "bg-primary text-primary-foreground" 
                    : "bg-secondary text-muted-foreground"
                )}
              >
                <Icon className="w-5 h-5" />
              </div>
              <span className={cn(
                "text-xs font-medium",
                isSelected ? "text-foreground" : "text-muted-foreground"
              )}>
                {itemType.label}
              </span>
              {isSelected && (
                <div className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">
                  {getItem(itemType.type)?.quantity || 1}
                </div>
              )}
            </button>
          );
        })}
      </div>

      {/* Item customization panels */}
      {items.map((item) => {
        const itemType = itemTypes.find(t => t.type === item.type);
        if (!itemType) return null;
        
        return (
          <div
            key={item.id}
            className="p-4 rounded-xl bg-secondary/30 border border-border space-y-3 animate-fade-in"
          >
            <div className="flex items-center justify-between">
              <span className="font-medium text-sm">{itemType.label} Options</span>
              <button
                type="button"
                onClick={() => toggleItem(item.type)}
                className="text-xs text-muted-foreground hover:text-destructive transition-colors"
              >
                Remove
              </button>
            </div>
            
            {/* Quantity */}
            <div className="flex items-center gap-3">
              <span className="text-sm text-muted-foreground w-16">Qty:</span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => updateItem(item.type, { quantity: Math.max(1, item.quantity - 1) })}
                  className="w-8 h-8 rounded-full bg-secondary hover:bg-secondary/80 flex items-center justify-center text-lg font-medium"
                >
                  -
                </button>
                <span className="w-8 text-center font-medium">{item.quantity}</span>
                <button
                  type="button"
                  onClick={() => updateItem(item.type, { quantity: Math.min(99, item.quantity + 1) })}
                  className="w-8 h-8 rounded-full bg-secondary hover:bg-secondary/80 flex items-center justify-center text-lg font-medium"
                >
                  +
                </button>
              </div>
            </div>

            {/* Colors */}
            <div className="flex items-center gap-3">
              <span className="text-sm text-muted-foreground w-16">Color:</span>
              <div className="flex gap-2 flex-wrap">
                {itemType.colors.map((color) => (
                  <button
                    key={color}
                    type="button"
                    onClick={() => updateItem(item.type, { color })}
                    className={cn(
                      "w-8 h-8 rounded-full border-2 transition-all",
                      item.color === color 
                        ? "border-foreground scale-110" 
                        : "border-transparent hover:scale-105"
                    )}
                    style={{ backgroundColor: color }}
                  />
                ))}
              </div>
            </div>

            {/* Custom message for some items */}
            {(item.type === "cake" || item.type === "gifts") && (
              <div className="flex items-center gap-3">
                <span className="text-sm text-muted-foreground w-16">Text:</span>
                <Input
                  placeholder={item.type === "cake" ? "Happy Birthday!" : "Special message"}
                  value={item.message || ""}
                  onChange={(e) => updateItem(item.type, { message: e.target.value })}
                  maxLength={50}
                  className="flex-1 h-9 text-sm"
                />
              </div>
            )}
          </div>
        );
      })}

      {items.length === 0 && (
        <p className="text-sm text-muted-foreground text-center py-2">
          Click items above to add celebration elements ✨
        </p>
      )}
    </div>
  );
}
