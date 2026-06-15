'use client';

import dynamic from 'next/dynamic';

// Aqui fazemos a importação dinâmica do Leaflet de forma segura no cliente
const MapaUfpe = dynamic(() => import('./MapaUfpe'), {
  ssr: false,
  loading: () => (
    <div className="h-[500px] w-full bg-gray-100 animate-pulse rounded-xl flex items-center justify-center text-gray-500">
      A carregar o mapa da UFPE...
    </div>
  )
});

// Este componente apenas repassa os dados para o mapa real
export default function MapWrapper({ centros }: { centros: any[] }) {
  return <MapaUfpe centros={centros} />;
}