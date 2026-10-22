-- Lock down public.rls_auto_enable().
--
-- That function is created by Supabase itself when the project setting
-- "Enable automatic RLS" is on. It is an event trigger helper: whenever a
-- table is created it switches Row Level Security on. Postgres already refuses
-- to run event trigger functions by hand, but by default every role may
-- EXECUTE a new function, and Supabase's Security Advisor flags that.
-- Removing the permission silences the warning and changes nothing else: the
-- event trigger itself runs with the owner's rights, not anon's.
--
-- Guarded with `to_regprocedure` because a plain local database may not have
-- the function at all, and this file must work in both places.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end
$$;
