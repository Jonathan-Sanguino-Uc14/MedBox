/** Display the supplied artwork without its large outer whitespace. */
export function BrandLogo({ className = "w-48" }: { className?: string }) {
  return (
    <svg
      viewBox="250 300 1100 290"
      role="img"
      aria-label="Med Box"
      className={`block h-auto shrink-0 ${className}`}
    >
      <image href="/medbox-logo.png" width="1600" height="893" />
    </svg>
  );
}
