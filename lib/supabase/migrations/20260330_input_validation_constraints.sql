-- Activity title: 3-100 characters
ALTER TABLE activities
  ADD CONSTRAINT chk_activity_title_length
  CHECK (length(title) BETWEEN 3 AND 100);

-- Activity description: max 2000 characters
ALTER TABLE activities
  ADD CONSTRAINT chk_activity_description_length
  CHECK (description IS NULL OR length(description) <= 2000);

-- User bio: max 200 characters
ALTER TABLE users
  ADD CONSTRAINT chk_user_bio_length
  CHECK (bio IS NULL OR length(bio) <= 200);

-- User name: 1-100 characters
ALTER TABLE users
  ADD CONSTRAINT chk_user_name_length
  CHECK (length(name) BETWEEN 1 AND 100);
