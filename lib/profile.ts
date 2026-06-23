export type Profile = {
  heightCm: number | null;
  weightKg: number | null;
  bodyType: string | null;
  skinTone?: string | null;
  styles: string[];
  colors: string[];
  occasions: string[];
  onboarded: boolean;
};

export type Option = { value: string; labelKey: string };
export type ColorOption = Option & { swatch: string };

export const HEIGHT_RANGE = { min: 140, max: 210, default: 165 };
export const WEIGHT_RANGE = { min: 35, max: 120, default: 55 };

export const BODY_TYPES: Option[] = [
  { value: "slim", labelKey: "bodySlim" },
  { value: "average", labelKey: "bodyAverage" },
  { value: "athletic", labelKey: "bodyAthletic" },
  { value: "curvy", labelKey: "bodyCurvy" },
  { value: "plus", labelKey: "bodyPlus" },
  { value: "rectangle", labelKey: "bodyRectangle" },
  { value: "triangle", labelKey: "bodyTriangle" },
  { value: "invertedTriangle", labelKey: "bodyInverted" },
  { value: "hourglass", labelKey: "bodyHourglass" },
  { value: "oval", labelKey: "bodyOval" },
];

export const SKIN_TONES: ColorOption[] = [
  { value: "fair", labelKey: "skinFair", swatch: "#F6DAC2" },
  { value: "light", labelKey: "skinLight", swatch: "#EAC1A0" },
  { value: "medium", labelKey: "skinMedium", swatch: "#D29E78" },
  { value: "olive", labelKey: "skinOlive", swatch: "#B98A5E" },
  { value: "tan", labelKey: "skinTan", swatch: "#9A6A43" },
  { value: "deep", labelKey: "skinDeep", swatch: "#6B4630" },
];

export const STYLES: Option[] = [
  { value: "casual", labelKey: "styleCasual" },
  { value: "streetwear", labelKey: "styleStreetwear" },
  { value: "minimal", labelKey: "styleMinimal" },
  { value: "formal", labelKey: "styleFormal" },
  { value: "sporty", labelKey: "styleSporty" },
  { value: "vintage", labelKey: "styleVintage" },
  { value: "elegant", labelKey: "styleElegant" },
  { value: "y2k", labelKey: "styleY2k" },
];

export const COLOR_TONES: ColorOption[] = [
  { value: "neutral", labelKey: "colorNeutral", swatch: "#a8a29e" },
  { value: "warm", labelKey: "colorWarm", swatch: "#f59e0b" },
  { value: "cool", labelKey: "colorCool", swatch: "#3b82f6" },
  { value: "pastel", labelKey: "colorPastel", swatch: "#f9a8d4" },
  { value: "earthy", labelKey: "colorEarthy", swatch: "#92400e" },
  { value: "bold", labelKey: "colorBold", swatch: "#ef4444" },
  { value: "monochrome", labelKey: "colorMonochrome", swatch: "#404040" },
  { value: "dark", labelKey: "colorDark", swatch: "#1f2937" },
];

export const OCCASIONS: Option[] = [
  { value: "work", labelKey: "occasionWork" },
  { value: "daily", labelKey: "occasionDaily" },
  { value: "sport", labelKey: "occasionSport" },
  { value: "party", labelKey: "occasionParty" },
  { value: "date", labelKey: "occasionDate" },
  { value: "travel", labelKey: "occasionTravel" },
  { value: "school", labelKey: "occasionSchool" },
];
