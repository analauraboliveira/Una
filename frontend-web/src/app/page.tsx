import { supabase } from './lib/supabase';
import MapWrapper from './components/MapWrapper';

export default async function Home() {
  // Usa a RPC PostGIS que retorna latitude/longitude já calculados
  const { data, error } = await supabase.rpc('get_nearest_collection_points', {
    p_lat: -8.0522,   // centro do campus UFPE (Recife)
    p_lng: -34.9511,
    p_radius_m: 5000,
    p_limit: 50,
  });

  if (error) return <main className="p-10 text-red-600">Erro Supabase: {error.message}</main>;

  const pontos = (data ?? []).map((p: any) => ({
    id: p.id,
    nome: p.name,
    sigla: p.building,
    lat: p.latitude,
    lon: p.longitude,
    qtd: p.total_stock,
    campus: p.campus,
  }));

  return (
    <main className="p-10 max-w-5xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Projeto Una — Pontos de Coleta UFPE</h1>
      {pontos.length > 0 ? (
        <MapWrapper centros={pontos} />
      ) : (
        <div className="p-10 border rounded-xl text-center">
          Nenhum ponto ativo encontrado. Verifique se as migrations e o seed foram aplicados no Supabase.
        </div>
      )}
    </main>
  );
}
