# Polish before Module 5: Photos, Categories, Contact and Profile

Plan and implementation record for the gaps closed after Module 4 and before the Maps module.

## Why

Modules 1–4 shipped with some pieces the documents call for but the app didn't have yet:

| Gap | Where the documents ask for it | Before |
|---|---|---|
| Business photos: a cover on cards and a gallery on the business page | Design notes: registration flow has a **Photos** step; the business page has a large cover image and a **Gallery**; "progressive image loading" | An unused `images` field; every card showed the colour gradient |
| Specific categories, plus "Other" | Feasibility report: "restaurants, cafes, shops, and service providers"; SRS **SCA-1**: new categories without code changes | 7 broad categories; the onboarding interests list was hard-coded in the app |
| Business phone number and a Call button | SDD data dictionary: `Business.phone` ("Contact number"); design: **Call** button on the business page | No phone field; the Call button did nothing |
| Editing your profile | Implementation plan, Module 1: "Edit profile functionality"; SDD `User.phone` | The API supported it but there was no screen; the Settings button did nothing |
| Profile photo | Requested alongside the above | Initials only |

## Decisions (confirmed with the project owner)

1. **Photos are stored in PostgreSQL.** This matches SDD §5.1 ("PostgreSQL stores all persistent application data"), needs no extra service, and works for the whole team on the shared database. Each photo is re-encoded to about 150–300 KB, so Supabase's free 500 MB holds roughly 1,500 photos.
2. **25 specific categories in 5 groups, plus "Other".** Choosing "Other" asks the owner what kind of business it is. That description is shown on cards and matched by search.
3. **Also fix:** business phone + Call, an edit-profile screen, and profile photos.

## What was built

### Photos

- **Upload** (`POST /media`, any signed-in user). The server:
  - accepts JPG, PNG or WebP up to 10 MB, at least 200 px on each side;
  - refuses decompression bombs;
  - turns phone photos upright and strips metadata, including any GPS location;
  - stores two progressive JPEGs: a large variant (1600 px long edge) for full-width surfaces and a thumbnail (480 px) for small tiles.
- **Focal point.** Each photo also gets a focal point, the centre of its visual detail, found from an edge map.
- **Serving** (`GET /media/{key}` and `/media/{key}/thumb`). A key never changes, so responses are cacheable for a year.
- **Galleries.** Up to 10 photos per business, and the first is the cover. They are set on create (`photos: [keys]`) or later with `PUT /businesses/{id}/photos`, in display order.
  - Removed photos are deleted, as are photos of deleted businesses.
  - Uploads that are never attached are cleaned up after 6 hours.
- **Automatic aspect ratio.** Cards crop the cover to their own shape (wide feature cards, 150×100 carousel cards, 64 px list thumbnails, compare cards, the 300 px page hero).
  - The crop centres the focal point as far as the photo's edges allow, so a storefront at the side of a wide photo stays whole in a square thumbnail.
  - Each tile picks the thumbnail or the large variant from the size it's drawn at. Large photos appear over their thumbnail first ("progressive image loading").
  - The gallery and the full-screen viewer show photos uncropped at their own aspect ratio, with swipe and pinch-to-zoom.
- **Fallback.** A business with no photos keeps the tone gradient, and owners can change that colour in *Edit business*.
- **Where owners manage photos.** The registration **Photos** step (between Location and About), and **Dashboard → Photos**. Both show the cover large, the rest in a grid, per-photo upload progress with retry, *Make this the cover* / *Remove*, and a "How your cover fits" preview in wide, square and tall frames.

### Categories

- **Categories are rows, not code.** New columns: `emoji`, `group_name`, `sort_order` and `keywords`. `GET /categories` returns them grouped and in order, with a published-business count.
- **Migration `b7d3f1a9c2e4`** upserts the catalogue by slug. Existing categories keep their ids (and so their businesses) and get clearer names, e.g. *Beauty* → *Beauty & Salons*, *Healthcare* → *Clinics & Doctors*.
- **"Other" + `custom_category`.** A description is required for "Other" and dropped for any other category. Cards show it as the business type (`category_label`).
- **Search.**
  - Keyword search matches category names, category **keywords** (local terms such as *darzi*, *dhaba*, *kiryana*, *dhobi*) and "Other" descriptions.
  - Typeahead suggests a category from its keywords (*darz* → Tailors & Fabric).
- **Pickers.** Registration, *Edit business*, onboarding interests, *Edit profile* interests, the filter sheet and Explore all use the grouped catalogue from the API with emoji chips.
  - Home, Explore and the filter sheet only offer categories that have businesses, so no chip leads to an empty result.

### Phone numbers and Call

- `businesses.phone` and `users.phone`. Both are optional, trimmed, and must have 7–15 digits.
- Registration's Location step became **Location & contact**.
- On the business page, **Call** opens the dialer (`tel:`), and the page shows the number under *Where*. Without a number, Call is dimmed and explains why.

### Edit profile

**Profile → Edit profile** (also the pencil button and a tap on the avatar) lets you change:
- photo, with add / change / remove
- name
- phone
- avatar colour
- interests, grouped

Email is shown read-only. The profile photo appears on Profile, the Home header and wherever the avatar is used.

### Also fixed while testing

- `GhostButton` always filled its width, so it failed to draw inside a `Row`. It now has `expand: false`.
- The Profile header was left-aligned; it's centred now.
- Category chips show the emoji in place of the dot, and use a dense style in long lists.
- Choosing a category in registration no longer overrides a colour the owner already picked.

## Endpoints

| Method | Path | Notes |
|---|---|---|
| POST | `/media` | Multipart `file`. Returns `{key, url, thumb_url, width, height, focal_x, focal_y}`. 413 over 10 MB; 422 for unreadable, too small or unsupported files |
| GET | `/media/{key}`, `/media/{key}/thumb` | JPEG, cached for a year |
| PUT | `/businesses/{id}/photos` | `{photos: [keys]}`, in order, the first is the cover. Owner only; each key must be yours or already in this gallery |
| POST / PATCH | `/businesses` | New fields `phone`, `custom_category`; `photos` on create |
| PATCH | `/users/me` | New fields `phone`, `avatar` (a media key; `null` removes it) |
| GET | `/categories` | Adds `emoji`, `group_name`, `sort_order`, `is_other`, `business_count` |

Business cards add `cover` and `category_label`; the business detail adds `photos`, `phone`, `category_id` and `custom_category`.

## Database changes (migration `b7d3f1a9c2e4`)

Additive only, so builds from before this change keep working against the same database:

- **New tables:**
  - `media` (the image bytes are deferred columns, so listing businesses never loads them)
  - `business_photos`
- **New nullable columns:**
  - `businesses.phone`, `businesses.custom_category`
  - `users.phone`, `users.avatar_media_id`
- **New columns with defaults:** `categories.emoji`, `group_name`, `sort_order`, `keywords`.
- **Category catalogue:** upserted by slug.
- **Legacy:** `businesses.images` is left in place, unused.

The downgrade removes these again and restores the old category names.

## Demo data

`python -m app.db.seed` (safe on the shared database) moves demo businesses into their specific categories:
- the four tailors → *Tailors & Fabric*
- CarePoint → *Pharmacies*
- Scoops & Swirls → *Bakeries & Sweets*
- The Dumpling Cart → *Street Food & Dhabas*
- Verse Bookshop → *Books & Stationery*

It also adds 13 businesses for the newer categories, including *Qalam Calligraphy Studio* under "Other". Demo phone numbers use `051 000 xxxx`: Islamabad-format numbers whose subscriber part starts with 0, which no real line uses, so Call can't ring a stranger. Demo businesses have no photos, so upload some to see them.

## Testing

- **Backend:** 117 tests pass, 28 of them new. They cover:
  - upload sizes and variants; EXIF rotation and metadata stripping; transparent PNGs
  - bad, tiny and oversized files; focal point placement; orphan cleanup
  - gallery create, reorder and remove; ownership and limits; cascade on delete
  - categories order and counts; "Other" rules; keyword and description search
  - phone validation; profile photo, name and phone
- **Flutter:** 31 tests pass, 9 of them new. They cover:
  - the photo model; crop centring; thumbnail vs large choice
  - category grouping; the "Other" and phone validators
  - the photo manager (add, cover, reorder, remove)
  - the edit-profile screen (photo, phone validation, interests, save)
- **Migration:** SQL rendered offline for Postgres (upgrade and downgrade).
- **Browser run** (Chrome at phone size, against a throwaway SQLite database with the demo seed):
  - owner: upload 3 photos; cards, search row, page hero, gallery and viewer; "Other" with a description shown on the page; full registration with category, phone and a photo, then publish
  - customer: profile photo and phone saved and shown on Profile and Home; *darzi* finds all five tailors; grouped filter categories
  - new sign-up: grouped interests from the API

## Rollout

1. `pip install -r requirements.txt` (adds Pillow) and `flutter pub get` (adds `image_picker`, `url_launcher`).
2. `alembic upgrade head` on the shared database.
3. `python -m app.db.seed` to refresh the demo businesses into the new categories.

iOS has photo-library and camera usage strings. Android and iOS declare the `tel:` scheme for Call.

## Not in this round

- **SRS UC-10 "Upload docs"** means verification documents for admin approval, not photos. It belongs with the Admin & Moderation module.
- **Directions** and **Share** on the business page still do nothing. Directions comes with the Maps module.
- **Photo reviews** belong to the Reviews module.
