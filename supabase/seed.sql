-- Données de la pile LOCALE uniquement (supabase db reset). Jamais jouées en
-- prod, où le mot de passe du worker vient du coffre ../.agora-secrets/.

-- Le worker local se connecte avec son propre rôle, pour que les droits
-- restreints de agora_worker soient éprouvés dès le développement.
alter role agora_worker with login password 'agora-worker-local';
