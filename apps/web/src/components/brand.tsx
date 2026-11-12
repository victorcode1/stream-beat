import Image from "next/image";
import Link from "next/link";
export function Brand() {
  return (
    <Link href="/" className="brand" aria-label="StreamBeat, inicio">
      <Image src="/icon.png" width={40} height={40} alt="" />
      <span>StreamBeat</span>
    </Link>
  );
}
