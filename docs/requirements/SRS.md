# Software Requirements Specification (SRS) for Khojlo

**Version 1.2 (working draft)**
COMSATS University Islamabad, Abbottabad Campus
Bachelor of Science in Software Engineering (2023–2027)

| Team member | Registration number |
|---|---|
| Sayyam Tahir | CIIT/SP23-BSE-014/ATD |
| Nouman Khan | CIIT/SP23-BSE-012/ATD |
| Kazim Shauket | CIIT/SP23-BSE-024/ATD |

**Supervisor:** Muhammad Tariq Baloch

> This is the editable copy of `SRS.pdf` (version 1.0). Items changed or added in version 1.1 are marked **(v1.1)**, and in version 1.2 **(v1.2)**. Paste the changes into the Word file before exporting the next PDF. Every issue found in the review, including the ones that need a team decision, is listed in [document_review.md](document_review.md).

## Revision History

| Name | Date | Reason for changes | Version |
|---|---|---|---|
| Project team | 2026 | Initial version | 1.0 |
| Nouman Khan | 28 Sep 2026 | Product name corrected to "Khojlo". Scope, operating environment and constraints aligned with the implementation. Added the missing requirements for profile management, account recovery, comparison, reporting, analytics, push notifications, personalization and chat (FR-16 to FR-25) and their use cases (UC-13 to UC-15). Resolved the UC-3 / BR-6 conflict. Added non-functional requirements for messaging. Added a module traceability table (Appendix A). | 1.1 |
| Sayyam Tahir | 30 Sep 2026 | Module 8 decisions: business verification is automatic, with admins reviewing the businesses the checks refer to them (FR-14, BR-3, BR-9, UC-12, SEC-2); admins can read a conversation once a participant reports it (BR-15, SEC-5); reporting covers conversations and businesses (FR-19). Added account moderation, automatic flagging, blocking, the Community Guidelines and the audit log (FR-26 to FR-30, BR-17 to BR-20, SEC-6), and use case tables for Manage Content, Manage Users and Monitor System (UC-16 to UC-18). | 1.2 |
| Nouman Khan | 30 Sep 2026 | Added privacy consent and account deletion (FR-31, FR-32, BR-21, BR-22) and the matching security requirements (SEC-7, SEC-8). | 1.2 |

## Application Evaluation History

| Comments (by committee) | Action taken |
|---|---|
| | |

---

## 1. Introduction

This section provides an overview of the Khojlo system and describes the objectives and scope of the Software Requirements Specification document.

### 1.1 Purpose

The purpose of this Software Requirements Specification (SRS) document is to define the functional and non-functional requirements of the Khojlo system. Khojlo is a mobile and web-based business discovery platform designed to help users find newly opened, affordable, and unique local businesses while providing business owners with a cost-effective way to increase their visibility. This document serves as a reference for developers, project supervisors, stakeholders, testers, and future maintainers throughout the development lifecycle.

### 1.2 Scope

Khojlo is a business discovery and comparison platform that enables users to explore, search, and compare local businesses through a structured and user-friendly interface. The system focuses on promoting newly established and value-driven businesses that often receive limited exposure on existing platforms.

The platform provides features such as user registration and profile management, business registration and management, discovery feeds for new and trending businesses, **push notifications about new businesses, trending listings and offers**, advanced search and filtering, business comparison, reviews and ratings, map-based location services, AI-powered chatbot assistance, **direct messaging between customers and business owners, AI-based personalized recommendations**, and administrative moderation tools. **(v1.1)**

The primary goal of Khojlo is to bridge the gap between customers and business owners by improving business visibility, accessibility, and informed decision-making. The system is limited to business discovery and comparison and does not support online ordering, payment processing, or delivery services.

## 2. Overall Description

Here is the overall description of the system.

### 2.1 Product Perspective

Khojlo is a new mobile and web-based business discovery platform developed to address the limitations of existing business listing and recommendation systems. Current platforms such as Google Maps and Yelp primarily promote well-established and highly rated businesses, making it difficult for newly opened and lesser-known businesses to gain visibility.

The proposed system is not a replacement for any existing platform but rather an independent product that complements existing business discovery services by focusing on newly opened, affordable, unique, and value-driven businesses. Khojlo introduces features such as business comparison, structured discovery feeds, location-based search, AI-assisted business information retrieval, **and direct communication between customers and businesses**. **(v1.1)**

### 2.2 Operating Environment

The Khojlo system will operate in the following environment:

- **OE-1:** The system shall operate on Android smartphones running Android 10.0 or later.
- **OE-2:** The system shall operate on modern web browsers including Google Chrome, Mozilla Firefox, Microsoft Edge and Apple Safari (latest versions).
- **OE-3:** The frontend application shall be developed using Flutter and Dart and shall support both mobile and web platforms.
- **OE-4:** The backend services shall be hosted on a cloud-based or dedicated server running a Linux operating system.
- **OE-5:** The backend application shall be developed using **Python 3.12 or later** and FastAPI. **(v1.1:** was "Python 3.12"; development uses Python 3.14.**)**
- **OE-6:** The database shall be implemented using **PostgreSQL 14 or later**. **(v1.1:** was "PostgreSQL 18.3 or later"; the team's local and shared databases run earlier versions.**)**
- **OE-7:** The system shall require a stable internet connection for accessing business information, maps, reviews, messages, and AI chatbot services.
- **OE-8:** The system shall integrate with Google Maps SDK and Google Maps APIs for location tracking, navigation, and map visualization.
- **OE-9:** Users, business owners, and administrators shall access the system remotely through the internet from their respective geographical locations.
- **OE-10 (v1.1):** The system shall use Firebase Cloud Messaging (FCM) to deliver push notifications to Android devices and web browsers.

### 2.3 Design and Implementation Constraints

- **CO-1:** The frontend of the system shall be developed using **Flutter 3.41+ and Dart 3.11+**. **(v1.1:** was "Flutter 3.24+ and Dart 3.5+ as specified in the project proposal"; the project now requires Dart 3.11.**)**
- **CO-2:** The backend of the system shall be developed using **Python 3.12 or later** and FastAPI. **(v1.1)**
- **CO-3:** The system shall use PostgreSQL as the primary database management system.
- **CO-4:** The system shall communicate between frontend and backend components through RESTful APIs. **Real-time features such as chat may additionally use a persistent WebSocket connection.** **(v1.1)**
- **CO-5:** The system shall use Google Maps APIs and Google Maps SDK for location-based services and navigation functionality.
- **CO-6:** The AI chatbot module shall use a Retrieval-Augmented Generation (RAG) approach and shall only provide responses based on information stored within the platform database.
- **CO-7:** The project shall follow Object-Oriented Design principles for system development and implementation.
- **CO-8:** The project shall be developed using the Agile Software Development methodology with the Scrum framework.
- **CO-9:** The system shall depend on internet connectivity and shall not support offline operation.
- **CO-10:** The scope of the system shall be limited to business discovery, comparison, reviews, ratings, **customer–business communication**, and information accessibility. Features such as online ordering, payment processing, and delivery services shall not be implemented. **(v1.1)**
- **CO-11 (v1.1):** Push notifications shall be sent through Firebase Cloud Messaging. iOS push notifications are out of scope, as they require a paid Apple Developer account.

## 3. Requirement Identifying Technique

The requirements for the Khojlo system were identified using the Use Case Modeling technique. This technique was selected because Khojlo is an interactive mobile and web-based application that involves direct interaction between different types of users and the system. Use cases help in understanding user goals, system behavior, and the functional requirements needed to achieve those goals. Figure 3.1 represents the use case diagram of the Khojlo system.

**Figure 3.1 Use case diagram of Khojlo.** The corrected diagram's source is [diagrams/use_case.puml](diagrams/use_case.puml). It can be rendered at plantuml.com, or imported into draw.io (Arrange → Insert → Advanced → PlantUML). Changes from version 1.0 **(v1.1)**:

- **Verify Business** is connected to the **Admin**, as UC-12 states, instead of the Business Owner. The owner's part (uploading documents) is covered by Register Business (UC-10).
- The "FireBase API" actor was connected to Login and Manage Profile, but login uses Google Sign-In and the system's own accounts, not Firebase. Login now connects to **Google Sign-In**, and **Firebase Cloud Messaging** connects to the new Receive Notifications use case.
- New use cases: **Message Business** (UC-13, extends View Business Details), **Respond to Messages** (UC-14) and **Receive Notifications** (UC-15).
- The Admin is connected to Login, as UC-1 lists the Admin as an actor.
- The "User" actor is renamed **Customer**, matching the use case tables, and the "Googel Maps API" typo is fixed.
- **(v1.2)** New use case **Report Content** (Customer and Business Owner), which feeds Manage Content. Manage Content, Manage Users and Monitor System now have tables (UC-16 to UC-18).

### 3.1 Use Case Descriptions

Use cases describe the interactions between the actors and the Khojlo system to achieve specific goals. They capture the functional requirements by defining the actors, triggers, preconditions, normal flow, alternative flows, exceptions, business rules, and postconditions.

**Table 3.1.1**

| Use Case ID | UC-1 |
|---|---|
| Use Case Name | Login |
| Actors | Customer, Business Owner, Admin |
| Description | Authenticates registered users. |
| Trigger | User selects Login. |
| Preconditions | Account exists. |
| Postconditions | User authenticated. |
| Normal Flow | 1. Open login page<br>2. Enter credentials<br>3. Validate credentials<br>4. Redirect to dashboard |
| Alternative Flows | Google login |
| Exceptions | Invalid credentials |
| Business Rules | Credentials must match records |
| Assumptions | Internet available |

**Table 3.1.2**

| Use Case ID | UC-2 |
|---|---|
| Use Case Name | Manage Profile |
| Actors | Customer, Business Owner |
| Description | Update profile information. |
| Trigger | Manage Profile selected. |
| Preconditions | Logged in. |
| Postconditions | Profile updated. |
| Normal Flow | 1. Open profile<br>2. Edit details<br>3. Validate<br>4. Save |
| Alternative Flows | Cancel update |
| Exceptions | Invalid data |
| Business Rules | Email unique |
| Assumptions | Authorized user |

**Table 3.1.3**

| Use Case ID | UC-3 |
|---|---|
| Use Case Name | Browse Business Feed |
| Actors | Customer |
| Description | Browse new and trending businesses. |
| Trigger | Open feed. |
| Preconditions | Businesses exist. |
| Postconditions | Feed displayed. |
| Normal Flow | 1. Open feed<br>2. Retrieve businesses<br>3. Display feed |
| Alternative Flows | Refresh |
| Exceptions | No businesses |
| Business Rules | **New businesses prioritized (BR-6)** **(v1.1:** was "Verified prioritized", which contradicted BR-6 under FR-11.**)** |
| Assumptions | Data available |

**Table 3.1.4**

| Use Case ID | UC-4 |
|---|---|
| Use Case Name | Search Businesses |
| Actors | Customer |
| Description | Search businesses by keyword. |
| Trigger | Enter search. |
| Preconditions | Businesses exist. |
| Postconditions | Results shown. |
| Normal Flow | 1. Enter keyword<br>2. Search<br>3. Display results |
| Alternative Flows | New keyword |
| Exceptions | No results |
| Business Rules | Rank by relevance |
| Assumptions | Internet |

**Table 3.1.5**

| Use Case ID | UC-5 |
|---|---|
| Use Case Name | Filter and Compare Businesses |
| Actors | Customer |
| Description | Filter and compare businesses. |
| Trigger | Choose filters. |
| Preconditions | Search results available. |
| Postconditions | Filtered comparison shown. |
| Normal Flow | 1. Apply filters<br>2. Select businesses<br>3. Compare |
| Alternative Flows | Clear filters |
| Exceptions | Comparison unavailable |
| Business Rules | Max comparison limit (BR-12) |
| Assumptions | Businesses available |

**Table 3.1.6**

| Use Case ID | UC-6 |
|---|---|
| Use Case Name | View Business Details |
| Actors | Customer |
| Description | View detailed business information. |
| Trigger | Select business. |
| Preconditions | Business exists. |
| Postconditions | Details displayed. |
| Normal Flow | 1. Select business<br>2. Retrieve details<br>3. Display details |
| Alternative Flows | Open map / reviews / **message the business (UC-13)** **(v1.1)** |
| Exceptions | Business unavailable |
| Business Rules | Suspended businesses aren't shown; verified ones carry the Verified badge (BR-3) **(v1.2)** |
| Assumptions | Profile exists |

**Table 3.1.7**

| Use Case ID | UC-7 |
|---|---|
| Use Case Name | Submit Reviews and Ratings |
| Actors | Customer |
| Description | Submit review. |
| Trigger | Click Add Review. |
| Preconditions | Logged in. |
| Postconditions | Review stored. |
| Normal Flow | 1. Open review<br>2. Enter rating/comment<br>3. Submit<br>4. Save |
| Alternative Flows | Edit review |
| Exceptions | Invalid review |
| Business Rules | One review per business |
| Assumptions | Customer visited |

**Table 3.1.8**

| Use Case ID | UC-8 |
|---|---|
| Use Case Name | Use AI Chatbot |
| Actors | Customer |
| Description | Ask business-related questions. |
| Trigger | Open chatbot. |
| Preconditions | Knowledge available. |
| Postconditions | Response displayed. |
| Normal Flow | 1. Ask query<br>2. Retrieve data<br>3. Generate response<br>4. Display |
| Alternative Flows | Ask another query |
| Exceptions | No answer |
| Business Rules | Uses platform data only |
| Assumptions | AI available |

**Table 3.1.9**

| Use Case ID | UC-9 |
|---|---|
| Use Case Name | View Maps |
| Actors | Customer |
| Description | View location and directions. |
| Trigger | Select View Maps. |
| Preconditions | Location exists. |
| Postconditions | Map shown. |
| Normal Flow | 1. Open map<br>2. Load Google Maps<br>3. Display location |
| Alternative Flows | Get directions |
| Exceptions | Location unavailable |
| Business Rules | Valid coordinates |
| Assumptions | Maps available |

**Table 3.1.10**

| Use Case ID | UC-10 |
|---|---|
| Use Case Name | Register Business |
| Actors | Business Owner |
| Description | Register new business. |
| Trigger | Register selected. |
| Preconditions | Logged in. |
| Postconditions | Registration submitted. |
| Normal Flow | 1. Enter details<br>2. Upload docs<br>3. Validate<br>4. Submit |
| Alternative Flows | Save draft |
| Exceptions | Missing fields |
| Business Rules | Unique business |
| Assumptions | Valid info |

**Table 3.1.11**

| Use Case ID | UC-11 |
|---|---|
| Use Case Name | Manage Offers |
| Actors | Business Owner |
| Description | Create/update offers. |
| Trigger | Manage Offers. |
| Preconditions | Business verified. |
| Postconditions | Offer saved. |
| Normal Flow | 1. Open offers<br>2. Add/Edit<br>3. Save |
| Alternative Flows | Deactivate offer |
| Exceptions | Invalid dates |
| Business Rules | Offer dates valid |
| Assumptions | Business active |

> **(v1.2)** The "Business verified" precondition stays. Verification is automatic (FR-14), so an owner meets it by passing the checks, without waiting for an admin.

**Table 3.1.12**

| Use Case ID | UC-12 **(v1.2)** |
|---|---|
| Use Case Name | Verify Business |
| Actors | System (automatic checks), Admin |
| Description | Give the Verified badge to businesses that pass the verification checks, and let an admin decide the ones the checks refer. |
| Trigger | The owner completes a check (email, listing, storefront photo), or the checks refer a business to an admin. |
| Preconditions | Business listed. For the admin: logged in as an admin. |
| Postconditions | Status updated (Verified, Pending Review, Needs Info or Rejected); the owner is notified. |
| Normal Flow | 1. Run the checks<br>2. All pass: mark Verified<br>3. All pass except the clean record: refer to an admin<br>4. Admin reviews the details, storefront photo, reports and flags<br>5. Approve or reject |
| Alternative Flows | Admin requests more info and the owner answers; admin revokes a badge |
| Exceptions | A check fails (the owner is told what's missing) |
| Business Rules | BR-9 |
| Assumptions | The owner can take a photo of the shop front |

**Table 3.1.13 (v1.1)**

| Use Case ID | UC-13 |
|---|---|
| Use Case Name | Message a Business |
| Actors | Customer (primary), Business Owner (secondary) |
| Description | Send an inquiry to a business about its products, services, prices, availability or appointments. |
| Trigger | Customer selects Message on a business profile. |
| Preconditions | Logged in. Business is published. |
| Postconditions | Message stored and delivered to the business owner. |
| Normal Flow | 1. Open business profile<br>2. Select Message<br>3. Type message<br>4. Send<br>5. Store message<br>6. Deliver to the owner |
| Alternative Flows | Continue an existing conversation from the Chat tab |
| Exceptions | Empty or too-long message; message not sent (retry) |
| Business Rules | Only the conversation's participants can read it (BR-15); a business owner can't message their own business |
| Assumptions | Internet available |

**Table 3.1.14 (v1.1)**

| Use Case ID | UC-14 |
|---|---|
| Use Case Name | Respond to Customer Messages |
| Actors | Business Owner |
| Description | Read and reply to customer inquiries. |
| Trigger | New message received, or owner opens the inbox. |
| Preconditions | Logged in. Owns the business. |
| Postconditions | Reply stored and delivered to the customer. |
| Normal Flow | 1. Open conversations<br>2. Select a conversation<br>3. Read messages<br>4. Type reply<br>5. Send |
| Alternative Flows | Open the conversation from a notification |
| Exceptions | Empty message; conversation unavailable |
| Business Rules | Only the business's owner replies on its behalf (BR-16) |
| Assumptions | Owner has a registered business |

**Table 3.1.15 (v1.1)**

| Use Case ID | UC-15 |
|---|---|
| Use Case Name | Receive Notifications |
| Actors | Customer, Business Owner; Firebase Cloud Messaging (secondary) |
| Description | Receive alerts about new businesses, trending listings, offers and messages. |
| Trigger | A notifiable event occurs, such as a new offer or a new message. |
| Preconditions | Logged in. Notifications allowed on the device. |
| Postconditions | Notification shown. Opening it shows the related screen. |
| Normal Flow | 1. Event occurs<br>2. System selects the recipients<br>3. System sends the notification<br>4. Device shows it<br>5. User opens it<br>6. Related screen shown |
| Alternative Flows | User has turned notifications off: nothing is sent to the device |
| Exceptions | Device unreachable or registration expired |
| Business Rules | Only users who allowed notifications receive them (BR-14) |
| Assumptions | Supported device or browser |

**Table 3.1.16 (v1.2)**

| Use Case ID | UC-16 |
|---|---|
| Use Case Name | Manage Content |
| Actors | Admin |
| Description | Decide on reported and automatically flagged content. |
| Trigger | A report or an automatic flag is open. |
| Preconditions | Admin logged in. |
| Postconditions | The content is removed or kept; the reports and flags are resolved; the people affected and the reporters are notified; the decision is logged. |
| Normal Flow | 1. Open the reports or flags queue<br>2. Open an item<br>3. Review the content, reports and flags<br>4. Remove it, giving a reason from the Community Guidelines<br>5. Optionally act on the account (UC-17) |
| Alternative Flows | Dismiss: the content stays |
| Exceptions | Already resolved by another admin |
| Business Rules | BR-10, BR-13 |
| Assumptions | Reported content is still available |

**Table 3.1.17 (v1.2)**

| Use Case ID | UC-17 |
|---|---|
| Use Case Name | Manage Users |
| Actors | Admin |
| Description | Warn, suspend, ban or reinstate an account. |
| Trigger | A decision in UC-16, or an admin looks up an account. |
| Preconditions | Admin logged in. |
| Postconditions | The account's standing is updated; the person is notified; the action is logged. |
| Normal Flow | 1. Find the account<br>2. Review its history, businesses and flags<br>3. Warn, suspend for a period, or ban, giving a reason |
| Alternative Flows | Lift a suspension or ban |
| Exceptions | Admin accounts can't be acted on |
| Business Rules | BR-17 |
| Assumptions | — |

**Table 3.1.18 (v1.2)**

| Use Case ID | UC-18 |
|---|---|
| Use Case Name | Monitor System |
| Actors | Admin |
| Description | See what needs attention and how the platform is doing. |
| Trigger | Admin opens the admin panel. |
| Preconditions | Admin logged in. |
| Postconditions | Overview displayed. |
| Normal Flow | 1. Open the overview<br>2. See the queues, today's numbers, 14-day activity and recent decisions<br>3. Open the audit log |
| Alternative Flows | Open a queue from the overview |
| Exceptions | Data unavailable |
| Business Rules | BR-20 |
| Assumptions | — |

## 4. Functional Requirements

The functional requirements describe the services and functions that the Khojlo system shall provide to its users. These requirements are organized according to the major features of the system. Requirements added in version 1.1 keep new numbers (FR-16 onwards), so existing references to FR-1 to FR-15 stay valid.

### 4.1 User Authentication and Profile Management

This feature enables users to register, log in, and manage their profiles.

**Table 4.1.1**

| Identifier | FR-1 |
|---|---|
| Title | User Registration |
| Requirement | The user shall be able to create a new account using email and password. |
| Source | User |
| Rationale | Allow new users to access the platform. |
| Business Rule | BR-1 Email must be unique |
| Dependencies | None |
| Priority | High |

**Table 4.1.2**

| Identifier | FR-2 |
|---|---|
| Title | User Login |
| Requirement | The user shall be able to log into the system using valid credentials. |
| Source | User |
| Rationale | Provide secure access to platform services. |
| Business Rule | BR-2 Credentials must be validated |
| Dependencies | FR-1 |
| Priority | High |

**Table 4.1.3 (v1.1)**

| Identifier | FR-16 |
|---|---|
| Title | Manage Profile |
| Requirement | The user shall be able to update their name, phone number, profile photo and interests. |
| Source | User |
| Rationale | Keep account information accurate and support personalization (UC-2). |
| Business Rule | BR-1 Email must be unique |
| Dependencies | FR-2 |
| Priority | High |

**Table 4.1.4 (v1.1)**

| Identifier | FR-17 |
|---|---|
| Title | Email Verification and Password Reset |
| Requirement | The system shall verify a user's email address and allow a forgotten password to be reset, using one-time codes sent by email. |
| Source | User |
| Rationale | Confirm account ownership and let users recover access. |
| Business Rule | BR-11 One-time codes expire after 10 minutes, and attempts and resends are limited |
| Dependencies | FR-1 |
| Priority | Medium |

**Table 4.1.5 (v1.2)**

| Identifier | FR-31 |
|---|---|
| Title | Privacy Consent |
| Requirement | The system shall show users a privacy policy explaining what personal data Khojlo collects (account, location, messages, device tokens), why, who can see it and how long it is kept. A user shall agree to it before using the app: on the sign-up form, or on a consent screen after Google sign-in or when the policy changes. The system shall record the policy version agreed to and when. The app shall explain why it needs the location before the device asks for permission. |
| Source | User, Legal |
| Rationale | Users should know how their data is used and give informed consent, and the team needs a record of it. |
| Business Rule | BR-21 A user must agree to the current policy version before using the app; the consent box is never pre-ticked |
| Dependencies | FR-1, FR-2 |
| Priority | High |

**Table 4.1.6 (v1.2)**

| Identifier | FR-32 |
|---|---|
| Title | Delete Account |
| Requirement | The user shall be able to permanently delete their account from the app. This removes their profile, photos, businesses, reviews, votes, reports, saved lists, conversations and messages, devices, notifications and search history. Counts shown to others (ratings, helpful votes, saves) shall be recalculated, and business view counts kept without the viewer. |
| Source | User, Legal |
| Rationale | Users control their own data. Google Play requires in-app account deletion for apps that let users create accounts. |
| Business Rule | BR-22 Deletion needs the account password (Google-only accounts confirm without one) and cannot be undone |
| Dependencies | FR-2 |
| Priority | High |

### 4.2 Business Discovery and Search

Users can discover, search, filter, compare and view detailed information about businesses.

**Table 4.2.1**

| Identifier | FR-3 |
|---|---|
| Title | Search Businesses |
| Requirement | The user shall be able to search businesses using keywords and categories. |
| Source | User |
| Rationale | Enable business discovery. |
| Business Rule | None |
| Dependencies | FR-2 |
| Priority | High |

**Table 4.2.2**

| Identifier | FR-4 |
|---|---|
| Title | Filter Businesses |
| Requirement | The user shall be able to filter businesses by category, location and price. |
| Source | User |
| Rationale | Improve search accuracy. |
| Business Rule | None |
| Dependencies | FR-3 |
| Priority | High |

**Table 4.2.3**

| Identifier | FR-5 |
|---|---|
| Title | View Business Details |
| Requirement | The system shall display complete business information. |
| Source | User |
| Rationale | Provide informed decision making. |
| Business Rule | BR-3 Suspended businesses aren't displayed; verified businesses carry the Verified badge **(v1.2:** was "Only verified business profiles displayed"; decision 1.**)** |
| Dependencies | FR-3 |
| Priority | High |

**Table 4.2.4 (v1.1)**

| Identifier | FR-18 |
|---|---|
| Title | Compare Businesses |
| Requirement | The user shall be able to compare selected businesses side by side on price, rating, services, offers and distance. |
| Source | User |
| Rationale | Support faster decisions (UC-5). |
| Business Rule | BR-12 Two to three businesses can be compared at a time |
| Dependencies | FR-3 |
| Priority | High |

### 4.3 User Reviews and Favorites

Users can leave reviews, submit ratings, and save favorite businesses for quick access.

**Table 4.3.1**

| Identifier | FR-6 |
|---|---|
| Title | Submit Reviews |
| Requirement | The user shall be able to submit ratings and reviews. |
| Source | User |
| Rationale | Support transparency and trust. |
| Business Rule | BR-4 One review per business per user |
| Dependencies | FR-2 |
| Priority | High |

**Table 4.3.2**

| Identifier | FR-7 |
|---|---|
| Title | Save Favorites |
| Requirement | The user shall be able to save businesses to favorites. |
| Source | User |
| Rationale | Allow quick future access. |
| Business Rule | None |
| Dependencies | FR-2 |
| Priority | Medium |

**Table 4.3.3 (v1.1)**

| Identifier | FR-19 |
|---|---|
| Title | Report Content |
| Requirement | The user shall be able to report a review, a conversation they take part in, or a business, giving a reason, for review by an admin. **(v1.2:** was reviews only.**)** |
| Source | User |
| Rationale | Give the admin moderation workflow (FR-15, SDD Algorithm 10) its "reported content". |
| Business Rule | BR-13 Each user can report an item once; reported content stays visible until an admin decides |
| Dependencies | FR-6 |
| Priority | Medium |

### 4.4 Business Owner Management

Business owners can register their businesses, manage profiles, create promotional offers and view analytics.

**Table 4.4.1**

| Identifier | FR-8 |
|---|---|
| Title | Business Registration |
| Requirement | Business owners shall be able to register businesses. |
| Source | Business Owner |
| Rationale | Allow businesses to join platform. |
| Business Rule | BR-5 Business verification required |
| Dependencies | FR-2 |
| Priority | High |

**Table 4.4.2**

| Identifier | FR-9 |
|---|---|
| Title | Manage Business Profile |
| Requirement | Business owners shall be able to update business information. **(v1.1:** grammar corrected from "shall be update".**)** |
| Source | Business Owner |
| Rationale | Maintain accurate information. |
| Business Rule | BR-5 Business verification required |
| Dependencies | FR-8 |
| Priority | High |

**Table 4.4.3**

| Identifier | FR-10 |
|---|---|
| Title | Manage Promotions |
| Requirement | Business owners shall create promotional offers. |
| Source | Business Owner |
| Rationale | Increase business visibility. |
| Business Rule | None |
| Dependencies | FR-9 |
| Priority | Medium |

**Table 4.4.4 (v1.1)**

| Identifier | FR-20 |
|---|---|
| Title | Business Analytics |
| Requirement | The system shall show business owners basic analytics for their businesses, such as profile views, saves and customer engagement. |
| Source | Business Owner |
| Rationale | Help owners understand their reach and visibility (Module 2). |
| Business Rule | None |
| Dependencies | FR-8 |
| Priority | Medium |

### 4.5 System Features

Core system features including the discovery feed, notifications, personalization, map integration, and AI chatbot support.

**Table 4.5.1**

| Identifier | FR-11 |
|---|---|
| Title | Discovery Feed |
| Requirement | The system shall display new and trending businesses. |
| Source | System |
| Rationale | Promote new businesses. |
| Business Rule | BR-6 New businesses prioritized |
| Dependencies | FR-8 |
| Priority | High |

**Table 4.5.2**

| Identifier | FR-12 |
|---|---|
| Title | Map Integration |
| Requirement | The system shall display business locations on maps. |
| Source | User |
| Rationale | Assist navigation. |
| Business Rule | BR-7 Valid GPS coordinates required |
| Dependencies | FR-5 |
| Priority | High |

**Table 4.5.3**

| Identifier | FR-13 |
|---|---|
| Title | AI Chatbot |
| Requirement | The system shall answer business-related queries using RAG. |
| Source | User |
| Rationale | Provide instant assistance. |
| Business Rule | BR-8 Responses based on stored platform data |
| Dependencies | FR-5 |
| Priority | High |

**Table 4.5.4 (v1.1)**

| Identifier | FR-21 |
|---|---|
| Title | Push Notifications |
| Requirement | The system shall notify users through push notifications about newly added businesses, trending listings, promotional offers and new messages. |
| Source | System |
| Rationale | Improve discovery and engagement (Module 3). |
| Business Rule | BR-14 Notifications are sent only to users who allowed them, and users can turn them off |
| Dependencies | FR-10, FR-11 |
| Priority | Medium |

**Table 4.5.5 (v1.1)**

| Identifier | FR-22 |
|---|---|
| Title | Personalized Recommendations |
| Requirement | The system shall recommend businesses based on the user's interests and activity, such as saves, views and searches. |
| Source | System |
| Rationale | Present more relevant businesses to each user (Module 10). |
| Business Rule | None |
| Dependencies | FR-11, FR-16 |
| Priority | Medium |

### 4.6 Admin and Moderation

Administrative functions for verifying business profiles and moderating platform content.

**Table 4.6.1**

| Identifier | FR-14 |
|---|---|
| Title | Business Verification **(v1.2)** |
| Requirement | The system shall verify a business automatically when its owner's email is verified, its listing is complete, the owner has taken a storefront photo in the app, and it has no open report or flag. Admins shall review the businesses the checks refer to them, and may verify, reject, request more information about, revoke or suspend any business. **(v1.2:** was "Admin shall verify business profiles before publication"; businesses are now listed on publication and verification adds the badge.**)** |
| Source | Admin |
| Rationale | Ensure authenticity without an admin having to approve every business by hand. |
| Business Rule | BR-9 Only the automatic checks or an admin can verify a business; only an admin can reject, revoke or suspend one **(v1.2)** |
| Dependencies | FR-8 |
| Priority | High |

**Table 4.6.2**

| Identifier | FR-15 |
|---|---|
| Title | Content Moderation |
| Requirement | Admin shall remove spam and inappropriate content. |
| Source | Admin |
| Rationale | Maintain platform quality. |
| Business Rule | BR-10 Content is removed according to the Community Guidelines (FR-29), and the people affected are told why **(v1.2)** |
| Dependencies | FR-14 |
| Priority | High |

**Table 4.6.3 (v1.2)**

| Identifier | FR-26 |
|---|---|
| Title | Account Moderation |
| Requirement | Admin shall be able to warn an account, suspend it for a period, ban it, or lift a suspension or ban. A suspended or banned account can't sign in or use the system. |
| Source | Admin |
| Rationale | Stop repeat offenders such as scammers and spammers (UC-17). |
| Business Rule | BR-17 Every action gives a reason from the Community Guidelines and is sent to the person; admin accounts can't be acted on |
| Dependencies | FR-15 |
| Priority | High |

**Table 4.6.4 (v1.2)**

| Identifier | FR-27 |
|---|---|
| Title | Automatic Flagging |
| Requirement | The system shall flag likely spam, scams, adult or prohibited content, fake reviews and duplicate listings for an admin to review. |
| Source | System |
| Rationale | Catch problems before anyone reports them (the design's "Spam" section). |
| Business Rule | BR-18 A flag never hides or changes content by itself, and private message text is never scanned |
| Dependencies | FR-15 |
| Priority | Medium |

**Table 4.6.5 (v1.2)**

| Identifier | FR-28 |
|---|---|
| Title | Block a Conversation |
| Requirement | Either participant shall be able to block a conversation, after which neither can send messages in it until the blocker unblocks it. |
| Source | User |
| Rationale | Protect people from harassment immediately, without waiting for an admin. |
| Business Rule | BR-19 Only the person who blocked a conversation can unblock it |
| Dependencies | FR-23 |
| Priority | Medium |

**Table 4.6.6 (v1.2)**

| Identifier | FR-29 |
|---|---|
| Title | Community Guidelines and Notices |
| Requirement | The system shall publish Community Guidelines, and shall notify users of decisions about their content, their account, their business's verification and their reports. |
| Source | Admin |
| Rationale | Make the moderation policy (BR-10) concrete and decisions transparent. |
| Business Rule | These notices can't be turned off |
| Dependencies | FR-15, FR-21 |
| Priority | Medium |

**Table 4.6.7 (v1.2)**

| Identifier | FR-30 |
|---|---|
| Title | Moderation Audit Log |
| Requirement | The system shall record every verification and moderation decision, with who made it (an admin or the automatic checks), when, and why, and show it to admins. |
| Source | Admin |
| Rationale | Accountability, and the admin overview and activity feed (UC-18). |
| Business Rule | BR-20 Audit entries can't be edited or deleted from the app |
| Dependencies | FR-14, FR-15 |
| Priority | Medium |

### 4.7 Chat and Messaging (v1.1)

Customers and business owners can communicate directly through one-to-one conversations.

**Table 4.7.1**

| Identifier | FR-23 |
|---|---|
| Title | Send Message to Business |
| Requirement | The user shall be able to send a text message to a business from its profile or from an existing conversation. |
| Source | User |
| Rationale | Let customers ask about products, services, prices, availability or appointments before visiting (UC-13). |
| Business Rule | BR-15 Only the two participants of a conversation can read its messages, except that admins can read a conversation once a participant reports it **(v1.2)** |
| Dependencies | FR-2, FR-5 |
| Priority | High |

**Table 4.7.2**

| Identifier | FR-24 |
|---|---|
| Title | Respond to Customer Messages |
| Requirement | Business owners shall be able to read and reply to customer messages in real time. |
| Source | Business Owner |
| Rationale | Improve customer support and engagement (UC-14). |
| Business Rule | BR-16 Only the business's owner can reply on its behalf |
| Dependencies | FR-8, FR-23 |
| Priority | High |

**Table 4.7.3**

| Identifier | FR-25 |
|---|---|
| Title | Manage Conversations |
| Requirement | The system shall list each user's conversations with the latest message and unread count, and mark messages as read when opened. |
| Source | User |
| Rationale | Let users keep track of ongoing inquiries. |
| Business Rule | None |
| Dependencies | FR-23 |
| Priority | Medium |

## 5. Non-Functional Requirements

This section describes the quality attributes and operational characteristics that the Khojlo system must satisfy to ensure a reliable, efficient, secure, and user-friendly experience.

### 5.1 Usability

The usability requirements ensure that users can easily learn and interact with the Khojlo system.

- **USE-1:** The system shall allow users to search for businesses using a maximum of three interactions from the home screen.
- **USE-2:** The system shall provide a consistent user interface across mobile and web platforms.
- **USE-3:** The system shall display clear validation messages whenever users enter invalid data.
- **USE-4:** The system shall allow users to access business details directly from search results with a single click/tap.
- **USE-5:** The AI chatbot interface shall always be accessible from the main navigation menu.
- **USE-6:** New users shall be able to complete account registration within 2 minutes under normal conditions.

### 5.2 Performance

The performance requirements define the expected speed and responsiveness of the system.

- **PER-1:** 95% of application pages shall load completely within 4 seconds over a 20 Mbps or faster internet connection.
- **PER-2:** The system shall return search results within 3 seconds for 95% of search requests.
- **PER-3:** The system shall display business profile details within 2 seconds after user selection.
- **PER-4:** The AI chatbot shall respond to user queries within 5 seconds for 90% of requests.
- **PER-5:** The system shall support at least 200 concurrent users without significant degradation in performance.
- **PER-6 (v1.1):** A chat message shall reach a recipient who has the app open within 2 seconds for 90% of messages.

### 5.3 Reliability

The system shall provide dependable and consistent operation.

- **REL-1:** The system shall maintain data integrity during all create, update, and delete operations.
- **REL-2:** The system shall automatically recover from temporary server failures without loss of stored data.
- **REL-3:** The system shall successfully process at least 99% of valid user requests.
- **REL-4:** User reviews, ratings, **messages** and business information shall remain persistent after system restarts. **(v1.1)**
- **REL-5 (v1.1):** Messages sent to a recipient who is offline shall be stored and shown when the recipient next opens the app.

### 5.4 Security

The system shall protect user data and prevent unauthorized access.

- **SEC-1:** All user passwords shall be stored in encrypted form.
- **SEC-2:** Only a business's owner shall be allowed to modify its profile; admins act on businesses only through the audited admin functions. **(v1.2:** was "Only verified business owners shall be allowed to modify business profiles".**)**
- **SEC-3:** Administrative functions shall be accessible only to authorized administrators.
- **SEC-4:** The system shall use secure HTTPS communication (and secure WebSockets, WSS, for real-time features) for all client-server interactions. **(v1.1)**
- **SEC-5 (v1.1):** A conversation's messages shall be accessible only to its participants, unless a participant reports the conversation for moderation. **(v1.2:** exception added.**)**
- **SEC-6 (v1.2):** Suspended and banned accounts shall be refused at sign-in and on every request.
- **SEC-7 (v1.2):** The system shall collect only the personal data a feature needs. The user's device location shall be used only for the request it was sent with and not stored against the user.
- **SEC-8 (v1.2):** Deleting an account shall remove the user's personal data from the database immediately, and their existing sessions shall stop working.

### 5.5 Scalability

The system shall be capable of handling future growth.

- **SCA-1:** The system architecture shall support the addition of new business categories without requiring major modifications.
- **SCA-2:** The system shall support future expansion to additional cities and geographical regions.
- **SCA-3:** The database shall support growth in the number of users, businesses, reviews, ratings **and messages** without significant performance degradation. **(v1.1)**

## 6. References

- International Organization for Standardization (ISO). (2018). *ISO/IEC/IEEE 29148:2018 Systems and Software Engineering — Life Cycle Processes — Requirements Engineering.* Geneva: ISO.
- Google. (2024). *Google Maps Platform Documentation.* https://developers.google.com/maps
- Google. (2026). *Firebase Cloud Messaging Documentation.* https://firebase.google.com/docs/cloud-messaging **(v1.1)**
- PostgreSQL Global Development Group. (2024). *PostgreSQL Documentation.* https://www.postgresql.org/docs/
- Pressman, R. S. (2020). *Software Engineering: A Practitioner's Approach.* New York: McGraw-Hill. **(v1.1:** "McGrew-Hill" corrected.**)**
- IEEE Computer Society. (2018). *IEEE Std 29148-2018: Systems and Software Engineering — Life Cycle Processes — Requirements Engineering.* New York: IEEE.
- Sommerville, I. (2016). *Software Engineering.* Boston: Pearson.

## Appendix A: Module Traceability (v1.1)

How the modules in the Feasibility Report map to the use cases and functional requirements above.

| # | Module | Use cases | Functional requirements |
|---|---|---|---|
| 1 | User Authentication and Profile Management | UC-1, UC-2 | FR-1, FR-2, FR-7, FR-16, FR-17, FR-31, FR-32 |
| 2 | Business Registration and Management | UC-10, UC-11 | FR-8, FR-9, FR-10, FR-20 |
| 3 | Business Discovery Feed (with push notifications) | UC-3, UC-6, UC-15 | FR-5, FR-11, FR-21 |
| 4 | Search, Filtering, and Comparison | UC-4, UC-5 | FR-3, FR-4, FR-18 |
| 5 | Reviews and Ratings | UC-7 | FR-6, FR-19 |
| 6 | Maps and Location Integration | UC-9 | FR-12 |
| 7 | AI Chatbot Assistance (RAG) | UC-8 | FR-13 |
| 8 | Admin and Moderation | UC-12, UC-16, UC-17, UC-18 | FR-14, FR-15, FR-19 (shared with Module 5), FR-26 to FR-30 |
| 9 | Chat and Messaging | UC-13, UC-14 | FR-23, FR-24, FR-25 |
| 10 | AI Personalization and Recommendation | — | FR-22 |
