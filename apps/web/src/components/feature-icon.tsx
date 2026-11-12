type Props = {
  name: "globe" | "radio" | "headphones" | "heart" | "share" | "sliders";
};
const paths = {
  globe: (
    <>
      <circle cx="12" cy="12" r="9" />
      <ellipse cx="12" cy="12" rx="4" ry="9" />
      <path d="M3 12h18" />
    </>
  ),
  radio: (
    <>
      <rect x="3" y="8" width="18" height="13" rx="3" />
      <path d="m5 8 13-5M6 12h5M6 16h3" />
      <circle cx="16" cy="15" r="2" />
    </>
  ),
  headphones: (
    <>
      <path d="M4 15v-3a8 8 0 0 1 16 0v3" />
      <rect x="3" y="12" width="5" height="8" rx="2" />
      <rect x="16" y="12" width="5" height="8" rx="2" />
    </>
  ),
  heart: (
    <path d="M20 5a5 5 0 0 0-8 1 5 5 0 0 0-8-1c-5 5 2 11 8 15 6-4 13-10 8-15Z" />
  ),
  share: (
    <>
      <circle cx="5" cy="12" r="3" />
      <circle cx="18" cy="5" r="3" />
      <circle cx="18" cy="19" r="3" />
      <path d="m8 10 7-4M8 14l7 4" />
    </>
  ),
  sliders: (
    <>
      <path d="M4 5h16M4 12h16M4 19h16" />
      <circle cx="8" cy="5" r="2" />
      <circle cx="16" cy="12" r="2" />
      <circle cx="10" cy="19" r="2" />
    </>
  ),
};
export function FeatureIcon({ name }: Props) {
  return (
    <svg
      className="feature-icon"
      aria-hidden="true"
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {paths[name]}
    </svg>
  );
}
