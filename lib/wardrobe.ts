export const WARDROBE_BUCKET = "wardrobe";

export type Category =
  | "Tops"
  | "Bottoms"
  | "Outerwear"
  | "Shoes"
  | "Accessories";

export const CATEGORIES: Category[] = [
  "Tops",
  "Bottoms",
  "Outerwear",
  "Shoes",
  "Accessories",
];

export type WardrobeItem = {
  id: string;
  name: string;
  category: Category;
  imagePath: string | null;
  imageUrl?: string;
};
