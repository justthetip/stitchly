"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

type Props = {
  title: string;
  message: string;
  next: string;
  className?: string;
  children: ReactNode;
};

export function AccountGateButton({ title, message, next, className, children }: Props) {
  const destination = encodeURIComponent(next);
  return (
    <Dialog>
      <DialogTrigger className={className}>{children}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{message}</DialogDescription>
        </DialogHeader>
        <DialogFooter className="sm:flex-col">
          <Link href={`/sign-in?mode=up&next=${destination}`} className="flex min-h-11 items-center justify-center rounded-xl bg-primary px-4 font-heading font-extrabold text-white">
            Create account
          </Link>
          <Link href={`/sign-in?mode=in&next=${destination}`} className="flex min-h-11 items-center justify-center rounded-xl border bg-white px-4 font-heading font-extrabold">
            Sign in
          </Link>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
