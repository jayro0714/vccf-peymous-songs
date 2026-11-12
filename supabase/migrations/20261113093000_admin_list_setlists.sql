-- Read-only, admin-only projection for the Manage > Setlists screen.
-- This function deliberately leaves the existing setlists RLS policies unchanged.
-- Drop the installed four-column signature before creating the two-column result.
DROP FUNCTION IF EXISTS public.admin_list_setlists();

CREATE FUNCTION public.admin_list_setlists()
RETURNS TABLE (
  setlist_name text,
  creator_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  caller_id uuid := auth.uid();
BEGIN
  IF caller_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.profiles AS caller_profile
    WHERE caller_profile.id = caller_id
      AND lower(btrim(caller_profile.role)) = 'admin'
      AND lower(btrim(caller_profile.status)) = 'approved'
  ) THEN
    RAISE EXCEPTION 'Not authorized to view Setlist creator details.'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    setlist.name::text,
    COALESCE(
      NULLIF(btrim(creator_profile.name), ''),
      NULLIF(btrim(creator.raw_user_meta_data ->> 'name'), ''),
      NULLIF(btrim(creator.raw_user_meta_data ->> 'full_name'), '')
    )::text
  FROM public.setlists AS setlist
  JOIN auth.users AS creator
    ON creator.id = setlist.user_id
  LEFT JOIN public.profiles AS creator_profile
    ON creator_profile.id = creator.id
  ORDER BY setlist.created_at DESC;
END;
$function$;

-- Pin ownership to the privileged database role so the narrow Auth join works
-- without granting clients direct access to auth.users or widening table RLS.
ALTER FUNCTION public.admin_list_setlists() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_list_setlists() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_setlists() TO authenticated;

-- Refresh PostgREST's cached return signature for the RPC endpoint.
NOTIFY pgrst, 'reload schema';
