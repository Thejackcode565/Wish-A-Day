import { useState } from "react";
import { format } from "date-fns";
import { CalendarIcon, Clock, Eye, Infinity } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

export type ExpiryType = "never" | "time" | "views";

interface ExpirySelectorProps {
  expiryType: ExpiryType;
  onExpiryTypeChange: (type: ExpiryType) => void;
  expiresAt?: Date;
  onExpiresAtChange: (date: Date | undefined) => void;
  maxViews?: number;
  onMaxViewsChange: (views: number | undefined) => void;
}

export function ExpirySelector({
  expiryType,
  onExpiryTypeChange,
  expiresAt,
  onExpiresAtChange,
  maxViews,
  onMaxViewsChange,
}: ExpirySelectorProps) {
  const options = [
    { value: "never" as ExpiryType, label: "Never expire", icon: Infinity },
    { value: "time" as ExpiryType, label: "Expire after time", icon: Clock },
    { value: "views" as ExpiryType, label: "Expire after views", icon: Eye },
  ];

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-2">
        {options.map((option) => {
          const Icon = option.icon;
          const isSelected = expiryType === option.value;
          return (
            <button
              key={option.value}
              type="button"
              onClick={() => {
                onExpiryTypeChange(option.value);
                if (option.value === "never") {
                  onExpiresAtChange(undefined);
                  onMaxViewsChange(undefined);
                }
              }}
              className={cn(
                "flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all duration-200",
                isSelected
                  ? "border-primary bg-primary/5 shadow-soft"
                  : "border-border hover:border-primary/30 hover:bg-secondary/50"
              )}
            >
              <Icon
                className={cn(
                  "w-5 h-5 transition-colors",
                  isSelected ? "text-primary" : "text-muted-foreground"
                )}
              />
              <span
                className={cn(
                  "text-xs font-medium text-center transition-colors",
                  isSelected ? "text-foreground" : "text-muted-foreground"
                )}
              >
                {option.label}
              </span>
            </button>
          );
        })}
      </div>

      {expiryType === "time" && (
        <div className="animate-slide-up">
          <Popover>
            <PopoverTrigger asChild>
              <Button
                variant="outline"
                className={cn(
                  "w-full justify-start text-left font-normal",
                  !expiresAt && "text-muted-foreground"
                )}
              >
                <CalendarIcon className="mr-2 h-4 w-4" />
                {expiresAt ? format(expiresAt, "PPP") : "Pick an expiry date"}
              </Button>
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="start">
              <Calendar
                mode="single"
                selected={expiresAt}
                onSelect={onExpiresAtChange}
                disabled={(date) => date < new Date()}
                initialFocus
                className="p-3 pointer-events-auto"
              />
            </PopoverContent>
          </Popover>
        </div>
      )}

      {expiryType === "views" && (
        <div className="animate-slide-up">
          <Select
            value={maxViews?.toString() || ""}
            onValueChange={(val) => onMaxViewsChange(parseInt(val))}
          >
            <SelectTrigger>
              <SelectValue placeholder="Select max views" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="1">1 view</SelectItem>
              <SelectItem value="2">2 views</SelectItem>
              <SelectItem value="5">5 views</SelectItem>
              <SelectItem value="10">10 views</SelectItem>
              <SelectItem value="25">25 views</SelectItem>
            </SelectContent>
          </Select>
        </div>
      )}
    </div>
  );
}
