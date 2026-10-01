# Khojlo Documentation

| Folder | Contents |
|---|---|
| [requirements/](requirements/) | The formal documents: Feasibility Report, SRS and SDD (PDFs as submitted), the editable SRS v1.1 and the documentation review. |
| [design/](design/) | The visual design: the Claude Design bundle, the HTML mockup, and the design notes. |
| [development_roadmap/](development_roadmap/) | The implementation plan for the 30%, 60% and 100% evaluations, and one plan / implementation record per module. |
| [team_setup.md](team_setup.md) | What to share privately with a teammate after they clone the project (`.env` values, key files). |

## Which document wins

When two sources disagree:

1. **Requirements** (`requirements/`) decide *what* the system does. If the code and the SRS differ, one of them is wrong; record it in [requirements/document_review.md](requirements/document_review.md) and fix it.
2. **The design bundle** (`design/Khojlo App.dc.html`) decides how screens look and the navigation: a floating 5-tab dock, Home · Explore · Map · Chat · Business. It overrides the prose notes in `design/modules_layout.md` and `design/ui_design_direction.md`.
3. **Module records** (`development_roadmap/moduleN_*.md`) describe what was actually built, the decisions behind it, and how it was tested.

## Design files

| File | What it is |
|---|---|
| [design/Khojlo App.dc.html](design/Khojlo%20App.dc.html) | Claude Design bundle with the app screens. Open it in a browser. |
| [design/khojlo-mockup/index.html](design/khojlo-mockup/index.html) | Standalone HTML mockup of the mobile app. |
| [design/theme.md](design/theme.md) | Colour palette and fonts. |
| [design/ui_design_direction.md](design/ui_design_direction.md) | The design prompt: overall direction, motion and micro-interactions. |
| [design/modules_layout.md](design/modules_layout.md) | Information architecture and screen layouts per module. |

## Module records

| Module | Record |
|---|---|
| 4. Search, Filtering and Comparison | [module4_search_filter_compare_plan.md](development_roadmap/module4_search_filter_compare_plan.md) |
| 5. Reviews and Ratings | [module5_reviews_ratings_plan.md](development_roadmap/module5_reviews_ratings_plan.md) |
| 6. Maps and Location | [module6_maps_location_plan.md](development_roadmap/module6_maps_location_plan.md) |
| 8. Admin and Moderation | [module8_admin_moderation_plan.md](development_roadmap/module8_admin_moderation_plan.md) |
| 9. Chat and Messaging, with push notifications (Module 3) | [module9_chat_and_push_plan.md](development_roadmap/module9_chat_and_push_plan.md) (includes the Firebase setup steps) · how it works: [module9_how_it_works.md](development_roadmap/module9_how_it_works.md) |
| Photos, categories, contact and profile (between Modules 4 and 5) | [polish_photos_categories_profile.md](development_roadmap/polish_photos_categories_profile.md) |

Modules 1–3 were built for the 30% evaluation before module records were kept; the [implementation plan](development_roadmap/implementation_plan.md) lists what they contain.
