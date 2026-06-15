'use client'; // Essencial: diz ao Next.js que este componente corre no navegador (cliente)

import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

// Correção para um bug comum do Leaflet no Next.js onde os ícones dos marcadores não carregam
const customIcon = L.icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

// Definição da estrutura de dados que vamos receber do banco
type CentroUFPE = {
  id: number;
  nome: string;
  sigla: string;
  lat: number;
  lon: number;
};

export default function MapaUfpe({ centros }: { centros: CentroUFPE[] }) {
  // Coordenadas centrais (focadas na Cidade Universitária da UFPE)
  const centroUfpe: [number, number] = [-8.0514, -34.9500];

  return (
    <div className="h-[500px] w-full rounded-xl overflow-hidden shadow-lg border border-gray-200">
      {/* Container principal do Mapa */}
      <MapContainer 
        center={centroUfpe} 
        zoom={15} 
        scrollWheelZoom={true} 
        className="h-full w-full"
        style={{ zIndex: 0 }} // Evita que o mapa cubra outros menus do site
      >
        {/* Camada visual do mapa baseada no OpenStreetMap */}
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        
        {/* Percorre a lista de centros e desenha um marcador para cada um */}
        {centros.map((centro) => (
          <Marker 
            key={centro.id} 
            position={[centro.lat, centro.lon]} 
            icon={customIcon}
          >
            <Popup>
              <div className="text-center">
                <strong className="text-blue-600 text-lg">{centro.sigla}</strong>
                <br />
                <span className="text-gray-700">{centro.nome}</span>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}