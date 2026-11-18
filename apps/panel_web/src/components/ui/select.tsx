import type { SelectHTMLAttributes } from "react";
import { cn } from "@/lib/utils";

export function Select({ className, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={cn(
        "min-h-10 rounded-md border border-[#d9e1dc] bg-white px-3 py-2 text-sm text-[#123a52] outline-none transition focus:border-[#123a52] focus:ring-2 focus:ring-sky-100",
        className,
      )}
      {...props}
    />
  );
}
