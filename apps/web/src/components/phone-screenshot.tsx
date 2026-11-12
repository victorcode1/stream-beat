import Image from "next/image";
type Props = {
  name: "home" | "radio" | "map";
  alt: string;
  priority?: boolean;
};
export function PhoneScreenshot({ name, alt, priority = false }: Props) {
  return (
    <div className="phone">
      <Image
        src={`/screenshots/${name}-es.png`}
        alt={alt}
        width={912}
        height={2048}
        sizes="(max-width: 600px) 65vw, 300px"
        priority={priority}
      />
    </div>
  );
}
