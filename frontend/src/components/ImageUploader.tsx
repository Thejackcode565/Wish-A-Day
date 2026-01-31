import { useState, useCallback } from "react";
import { X, Upload, Image as ImageIcon } from "lucide-react";
import { cn } from "@/lib/utils";

interface ImageUploaderProps {
  images: File[];
  onImagesChange: (images: File[]) => void;
  maxImages?: number;
  maxSizeMB?: number;
}

export function ImageUploader({
  images,
  onImagesChange,
  maxImages = 5,
  maxSizeMB = 2,
}: ImageUploaderProps) {
  const [dragActive, setDragActive] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const validateFile = (file: File): boolean => {
    if (!file.type.startsWith("image/")) {
      setError("Only image files are allowed");
      return false;
    }
    if (file.size > maxSizeMB * 1024 * 1024) {
      setError(`File size must be less than ${maxSizeMB}MB`);
      return false;
    }
    return true;
  };

  const handleFiles = useCallback(
    (files: FileList | null) => {
      if (!files) return;
      setError(null);

      const newFiles: File[] = [];
      const remaining = maxImages - images.length;

      for (let i = 0; i < Math.min(files.length, remaining); i++) {
        const file = files[i];
        if (validateFile(file)) {
          newFiles.push(file);
        }
      }

      if (files.length > remaining) {
        setError(`You can only upload ${maxImages} images total`);
      }

      if (newFiles.length > 0) {
        onImagesChange([...images, ...newFiles]);
      }
    },
    [images, maxImages, maxSizeMB, onImagesChange]
  );

  const handleDrag = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  }, []);

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      e.stopPropagation();
      setDragActive(false);
      handleFiles(e.dataTransfer.files);
    },
    [handleFiles]
  );

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    handleFiles(e.target.files);
    e.target.value = "";
  };

  const removeImage = (index: number) => {
    onImagesChange(images.filter((_, i) => i !== index));
    setError(null);
  };

  const isDisabled = images.length >= maxImages;

  return (
    <div className="space-y-4">
      <div
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
        className={cn(
          "relative border-2 border-dashed rounded-xl p-8 text-center transition-all duration-200",
          dragActive && !isDisabled && "border-primary bg-primary/5 scale-[1.02]",
          isDisabled
            ? "border-muted bg-muted/50 cursor-not-allowed"
            : "border-border hover:border-primary/50 cursor-pointer"
        )}
      >
        <input
          type="file"
          accept="image/*"
          multiple
          onChange={handleInputChange}
          disabled={isDisabled}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer disabled:cursor-not-allowed"
        />
        <div className="flex flex-col items-center gap-3">
          <div
            className={cn(
              "w-14 h-14 rounded-full flex items-center justify-center transition-colors",
              isDisabled ? "bg-muted" : "bg-primary/10"
            )}
          >
            <Upload
              className={cn(
                "w-6 h-6",
                isDisabled ? "text-muted-foreground" : "text-primary"
              )}
            />
          </div>
          <div>
            <p className="font-medium text-foreground">
              {isDisabled ? "Maximum images reached" : "Drop images here or click to upload"}
            </p>
            <p className="text-sm text-muted-foreground mt-1">
              Max {maxImages} images, {maxSizeMB}MB each
            </p>
          </div>
        </div>
      </div>

      {error && (
        <p className="text-sm text-destructive animate-fade-in">{error}</p>
      )}

      {images.length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-3">
          {images.map((file, index) => (
            <div
              key={index}
              className="relative group aspect-square rounded-xl overflow-hidden shadow-soft animate-fade-in"
            >
              <img
                src={URL.createObjectURL(file)}
                alt={`Upload ${index + 1}`}
                className="w-full h-full object-cover"
              />
              <div className="absolute inset-0 bg-foreground/0 group-hover:bg-foreground/20 transition-colors" />
              <button
                type="button"
                onClick={() => removeImage(index)}
                className="absolute top-2 right-2 w-7 h-7 rounded-full bg-background/90 backdrop-blur-sm flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity hover:bg-destructive hover:text-destructive-foreground"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>
      )}

      <p className="text-xs text-muted-foreground text-center">
        {images.length} / {maxImages} images
      </p>
    </div>
  );
}
