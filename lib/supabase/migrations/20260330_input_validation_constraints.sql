-- Activity title: 3-100 characters
DO $$ BEGIN
  ALTER TABLE activities ADD CONSTRAINT chk_activity_title_length CHECK (length(title) BETWEEN 3 AND 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Activity description: max 2000 characters
DO $$ BEGIN
  ALTER TABLE activities ADD CONSTRAINT chk_activity_description_length CHECK (description IS NULL OR length(description) <= 2000);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- User bio: max 200 characters
DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT chk_user_bio_length CHECK (bio IS NULL OR length(bio) <= 200);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- User name: 1-100 characters
DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT chk_user_name_length CHECK (length(name) BETWEEN 1 AND 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
