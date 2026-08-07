"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BookOpen, Layers, Plus, UserRound } from "lucide-react";
import { cn } from "@/lib/utils";

const tabs = [
  {
    href: "/projects",
    label: "Projects",
    icon: Layers,
    match: (p: string) => p.startsWith("/projects"),
  },
  {
    href: "/library",
    label: "Library",
    icon: BookOpen,
    match: (p: string) => p.startsWith("/library") && p !== "/library/upload",
  },
  { href: "/library/upload", label: "Add", icon: Plus, match: (p: string) => p === "/library/upload", prominent: true },
  { href: "/account", label: "You", icon: UserRound, match: (p: string) => p.startsWith("/account") },
];

export function BottomNav() {
  const pathname = usePathname();
  // Hide nav on the immersive reader screen
  const isReader = /^\/projects\/[^/]+\/reader/.test(pathname) || pathname === "/sign-in";
  if (isReader) return null;

  return (
    <nav className="absolute inset-x-0 bottom-0 z-30 border-t border-border/80 bg-background/90 backdrop-blur-xl">
      <div className="relative mx-auto grid max-w-xl grid-cols-4">
        {tabs.map((tab) => {
          const active = tab.match(pathname);
          const Icon = tab.icon;
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={cn(
                "flex flex-col items-center gap-1 py-3 text-[10px] font-bold tracking-wide",
                active ? "text-primary" : "text-muted-foreground"
              )}
            >
              {tab.prominent ? (
                <span className="-mt-10 mb-1 flex size-14 items-center justify-center rounded-2xl bg-primary text-primary-foreground shadow-lg shadow-primary/30 ring-4 ring-background rotate-3">
                  <Icon className="size-5" strokeWidth={2.5} />
                </span>
              ) : (
                <Icon className="size-5" strokeWidth={active ? 2.2 : 1.8} />
              )}
              {tab.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
