import Image from "next/image";
import { PatternArt } from "@/components/craft-art";
import { cn } from "@/lib/utils";

type PatternCoverProps = {
  coverUrl?: string | null;
  craft: "knit" | "crochet";
  index?: number;
  className?: string;
  fallbackClassName?: string;
  alt?: string;
};

export function PatternCover({ coverUrl, craft, index, className, fallbackClassName, alt = "Pattern cover" }: PatternCoverProps) {
  if (coverUrl) {
    return <Image src={coverUrl} alt={alt} fill unoptimized sizes="(max-width: 768px) 50vw, 33vw" className={cn("object-cover", className)} />;
  }

  return <PatternArt index={index ?? (craft === "knit" ? 0 : 1)} className={fallbackClassName} />;
}
