import { supabase } from './lib/supabase';
import MapWrapper from './components/MapWrapper';

export default async function Home() {
  const { data, error } = await supabase.from('centros_ufpe').select('*');

  if (error) return <main className="p-10 text-red-600">Erro Supabase: {error.message}</main>;

  const centros = data?.map(c => ({
    ...c,
    lat: c.coordenadas?.coordinates ? c.coordenadas.coordinates[1] : 0,
    lon: c.coordenadas?.coordinates ? c.coordenadas.coordinates[0] : 0
  }));

  return (
    <main className="p-10 max-w-5xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Projeto Una - Mapa Espacial</h1>
      {centros && centros.length > 0 ? (
        <MapWrapper centros={centros} />
      ) : (
        <div className="p-10 border rounded-xl text-center">Tabela vazia. Por favor, execute o INSERT no SQL Editor do Supabase.</div>
      )}
    </main>
  );
}
