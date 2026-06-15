'use client';
import dynamic from 'next/dynamic';

const MapaUfpe = dynamic(() => import('./MapaUfpe'), {
  ssr: false,
  loading: () => <div className="h-[500px] w-full bg-gray-100 flex items-center justify-center">Carregando mapa...</div>
});

export default function MapWrapper({ centros }: { centros: any[] }) {
  return <MapaUfpe centros={centros} />;
}
