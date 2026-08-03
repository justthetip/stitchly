import Image from "next/image";
import { cn } from "@/lib/utils";

type PatternCoverProps = {
  coverUrl?: string | null;
  craft: "knit" | "crochet";
  kind?: "pattern" | "project";
  index?: number;
  className?: string;
  alt?: string;
};

export function PatternCover({ coverUrl, kind = "pattern", className, alt = "Pattern cover" }: PatternCoverProps) {
  if (coverUrl) {
    return <Image src={coverUrl} alt={alt} fill unoptimized sizes="(max-width: 768px) 50vw, 33vw" className={cn("object-cover", className)} />;
  }

  return <Image src={`/illustrations/${kind}-fallback.png`} alt="" fill sizes="(max-width: 768px) 50vw, 33vw" className={cn("object-cover", className)} />;
}
