-- ============================================================
-- LeadTown AI — CIERRE DEL AGUJERO DEL PLAN GRATIS
-- Ejecutar en: Supabase Dashboard > SQL Editor > Run
-- Fecha: 2026-08-19
-- ============================================================
--
-- PROBLEMA:
--   La política "Users update own profile" permite al usuario
--   actualizar CUALQUIER columna de su propio perfil, incluidas
--   'plan' y 'plan_active'. Como la anon key es pública (está en
--   el HTML), cualquiera podía darse el plan Élite gratis con una
--   línea en la consola del navegador:
--
--     supabase.from('profiles')
--             .update({plan:'elite', plan_active:true})
--             .eq('id', <su propio id>)
--
--   Es decir: pagar era opcional.
--
-- SOLUCIÓN:
--   Permisos a nivel de COLUMNA. El usuario sigue pudiendo editar
--   sus ajustes (nombre, ciudades, objetivos), pero 'plan',
--   'plan_active', 'stripe_customer_id' y 'stripe_subscription_id'
--   quedan fuera de su alcance. Esas 4 solo las escribe el webhook
--   de Stripe, que usa la service key y se salta RLS.
-- ============================================================

-- 1. Quitar el UPDATE global sobre profiles a los roles públicos
revoke update on public.profiles from authenticated;
revoke update on public.profiles from anon;

-- 2. Devolver el UPDATE SOLO sobre las columnas que el usuario
--    sí debe poder cambiar desde la web
grant update (
  name,
  email,
  avatar_url,
  cities,
  price_per_web,
  monthly_goal,
  updated_at
) on public.profiles to authenticated;

-- 3. (anon no necesita escribir nada en profiles)

-- ============================================================
-- COMPROBACIÓN
-- Debe devolver exactamente las 7 columnas del grant de arriba.
-- Si aparece 'plan' o 'plan_active' en la lista, algo ha fallado.
-- ============================================================
select grantee, column_name, privilege_type
from information_schema.column_privileges
where table_schema = 'public'
  and table_name   = 'profiles'
  and grantee      = 'authenticated'
  and privilege_type = 'UPDATE'
order by column_name;

-- ============================================================
-- NOTA IMPORTANTE (no lo arregla este SQL):
--   Los 9.567 leads viajan al navegador dentro de real-leads.js
--   (1,8 MB) para TODO el que abra leadtown.es, haya pagado o no.
--   Esto cierra el "plan gratis", pero no impide que alguien lea
--   los leads desde las DevTools sin registrarse siquiera.
--   Para cerrar eso de verdad hay que servir los leads desde una
--   API autenticada que filtre por plan en el servidor.
-- ============================================================
