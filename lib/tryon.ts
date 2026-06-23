export type TryonCategory = "tops" | "bottoms" | "one-pieces";

export function categoryForGarment(category: string): TryonCategory {
  if (category === "Bottoms") {
    return "bottoms";
  }
  return "tops";
}

// Sample full-body model photos. Replace these URLs with your own hosted
// full-body model images (front-facing, clear) any time.
export const DEFAULT_MODELS: { id: string; url: string }[] = [
  {
    id: "m1",
    url: "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=720&h=1080&fit=crop",
  },
  {
    id: "m2",
    url: "https://images.unsplash.com/photo-1492288991661-058aa541ff43?w=720&h=1080&fit=crop",
  },
];
