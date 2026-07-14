

#### **SCOPE DOCUMENT REVSION HISTORY** 

|**No.**|**Comment**<br>**Action**|
|---|---|



#### **Supervisor Signature** 

#### **Date:** 

## Contents 

|**Abstract**.........................................................................................................................................................4|
|---|
|**Introduction**..................................................................................................................................................5|
|**Problem Statement**.......................................................................................................................................5|
|**Problem Solution for Proposed System**.....................................................................................................6|
|**Related System Analysis/Literature Review**..............................................................................................6|
|**Advantages/Benefits of Proposed System**..................................................................................................8|
|**Scope**.............................................................................................................................................................8|
|**Modules**.........................................................................................................................................................9|
|**Module 1:**User Authentication and Profile Management........................................................................9|
|**Module 2:**Business Registration and Management..................................................................................9|
|**Module 3:**Business Discovery Feed (New & Trending Businesses).......................................................9|
|**Module 4:**Search, Filtering, and Comparison System.............................................................................9|
|**Module 5:**Location and Map Integration Module..................................................................................10|
|**Module 6:**Reviews and Ratings System................................................................................................10|
|**Module 7:**AI Chatbot Assistance Module..............................................................................................10|
|**System Limitations/Constraints**...............................................................................................................10|
|**Software Process Methodology**.................................................................................................................11|
|**Tools and Technologies**..............................................................................................................................11|
|**Project Stakeholders and Roles**................................................................................................................12|
|**Team Members Individual Tasks/Work Division**....................................................................................12|
|**Data Gathering Approach**.........................................................................................................................13|
|**Concepts**......................................................................................................................................................13|
|**Gantt chart**.................................................................................................................................................15|
|**Mockups**......................................................................................................................................................16|
|**Conclusion**.................................................................................................................................................17s|
|**References**...................................................................................................................................................17|
|**Plagiarism Report**......................................................................................................................................17|



### **Project Category: (** Select all the major domains of proposed project **)** 

**A-** Desktop Application/Information System **B-** Web Application/Web Application based Information System **C-** Problem Solving and Artificial Intelligence **D-** Simulation and Modeling **E-** Smartphone Application **F-** Smartphone Game **G-** Networks **H-** Image Processing Other (specify category) ______________________ 

# **Abstract** 

Khojlo is a mobile and web-based application developed using Flutter for the frontend and FastAPI (Python) for the backend. The system is designed to improve the discovery of local businesses by addressing the limitations of existing platforms. Currently, users often struggle to find newly opened, affordable, or unique businesses in their area, as most platforms prioritize popular and highly rated listings. At the same time, business owners, especially those with new ventures or special offerings—face difficulties in promoting their services without investing heavily in marketing. Khojlo provides a centralized platform that connects customers with businesses more effectively by focusing on visibility, accessibility, and value. 

The application allows users to explore newly opened businesses, compare options based on pricing and value, and discover unique products or services offered in the market. It includes features such as a dedicated discovery feed for emerging businesses, verified business profiles managed by owners, smart filtering based on user preferences, and integration with Google Maps for location tracking. Additionally, a lightweight AI chatbot assists users by answering basic queries about businesses, such as operating hours and available services. By prioritizing new, competitive, and value-driven businesses, Khojlo enhances user decision-making while providing businesses with a cost-effective way to reach their target audience. 

# **Introduction** 

This project proposal document presents the concept, purpose, and feasibility of the system “Khojlo,” a platform designed to improve the discovery of local businesses. In today’s digital era, users rely heavily on online platforms to search for businesses, products, and services in their local areas. However, existing platforms often prioritize well-established and highly rated businesses, making it difficult for newly opened or lesser-known businesses to gain visibility. As a result, users may miss out on better-priced options, unique offerings, or improved services available in the market. 

At the same time, business owners, particularly those who are new or introducing innovative products and services, face challenges in reaching potential customers without investing significantly in marketing and promotions. This creates a gap between customers seeking better options and businesses trying to offer value. Additionally, business information on many platforms can be outdated, unstructured, or difficult to compare effectively. Khojlo aims to address these challenges by providing a structured and accessible platform that focuses on highlighting new, competitive, and value-driven businesses. The system will allow users to explore, compare, and interact with businesses more efficiently while enabling business owners to manage and present their offerings directly. 

# **Problem Statement** 

In the current digital landscape, users rely on online platforms to search for businesses, products, and services in their local areas. However, most existing platforms prioritize well-established and highly rated businesses, making it difficult for users to discover newly opened or lesser-known businesses. As a result, users often miss out on better-priced options, unique offerings, or improved services available in the market. Additionally, there is no structured way to highlight businesses that provide better value or introduce new products and services. Users are often required to manually compare multiple options, which can be time-consuming and inefficient. 

On the other hand, business owners, especially those who have recently started their businesses, face challenges in promoting their services to potential customers. Many of them are required to spend significant amounts on marketing, yet still struggle to gain visibility. Even businesses that offer competitive pricing or unique services are often overlooked due to the lack of a proper platform. Existing systems such as Google Maps and similar platforms provide basic listings but do not focus on promoting new or value-driven businesses effectively. 

Khojlo is being developed to address these limitations by providing a platform that focuses on the discovery of new, affordable, and unique businesses in a structured way. It aims to bridge the gap 

between customers and business owners by improving visibility and accessibility. While similar systems already exist, this project re-implements and enhances the concept by focusing specifically on discovery, comparison, and value-based filtering. This re-implementation will help in understanding real-world system design, user experience challenges, and backend integration. Through this project, skills in Flutter development, FastAPI backend development, API integration, and system design will be developed. Additionally, the project will provide practical experience in building scalable applications and implementing features such as search, filtering, and AI-based assistance. 

# **Problem Solution for Proposed System** 

The proposed system, Khojlo, addresses the limitations of existing platforms by providing a dedicated space for discovering new, affordable, and unique businesses. It introduces a structured discovery mechanism that highlights newly opened and emerging businesses, making them easily visible to users. This ensures that users do not miss out on better options that are often hidden on traditional platforms. The system also allows businesses to create and manage verified profiles, ensuring that the information provided is accurate and up to date. By giving control to business owners, Khojlo reduces the chances of outdated or misleading data. 

To improve user decision-making, the system offers comparison features that allow users to evaluate businesses based on pricing and value. This reduces the need for manual comparison across multiple platforms and saves time for users. Additionally, smart filtering options based on location, category, and preferences help users find relevant businesses quickly and efficiently. Integration with mapping services enables users to easily locate and navigate to businesses without external effort. 

Khojlo also incorporates a lightweight AI chatbot that assists users by answering basic queries such as business hours, services, and available deals. This enhances user interaction and provides quick access to important information that may not be directly visible. By focusing on new and value-driven businesses, the platform creates opportunities for business owners to promote their offerings without relying heavily on paid marketing. Overall, the system bridges the gap between customers and businesses by improving visibility, accessibility, and decision-making. This approach ensures a more efficient and user-centered business discovery experience. 

# **Related System Analysis/Literature Review** 

Several existing platforms provide business discovery and listing services, but they have limitations that affect user experience and business visibility. 

**Google Maps** is one of the most widely used platforms for discovering nearby businesses. It provides location-based search, user reviews, ratings, and navigation features. However, it primarily highlights popular and highly rated businesses, making it difficult for newly opened or lesser-known businesses to gain visibility. Additionally, it lacks structured comparison features for evaluating businesses based on value or pricing. 

**Yelp** is another platform that focuses on user reviews and ratings for businesses such as restaurants and services. It helps users make decisions based on community feedback and experiences. However, Yelp also prioritizes established businesses with more reviews, which limits the exposure of new businesses. It does not provide a dedicated mechanism to highlight unique offerings or newly introduced services. 

**Facebook** also supports business listings and promotions through pages and advertisements. Businesses can share updates, offers, and interact with customers directly. However, content visibility is heavily dependent on algorithms and paid promotions, making it difficult for new businesses to reach a wider audience organically. Additionally, it is not specifically designed for structured business discovery and comparison. 

**Table 1 Related System Analysis with proposed project solution** 

|**Application Name**|**Weakness**|**Proposed Project Solution**|
|---|---|---|
|Google Maps|Focuses on popular<br>businesses, limited support<br>for new business discovery,<br>no structured comparison|Provides a dedicated discovery<br>feed for newly opened<br>businesses and comparison<br>based onpricing/value|
|Yelp|Relies heavily on reviews,<br>new businesses lack<br>visibility, no focus on<br>unique offerings|Highlights new and unique<br>businesses with structured<br>listing and filtering|
|Facebook|Requires paid promotion for<br>reach, unstructured<br>discovery, algorithm-<br>dependent visibility|Offers organic visibility<br>through structured discovery<br>and category-based filtering|



# **Advantages/Benefits of Proposed System** 

1. The proposed system improves business discovery by helping users easily find newly opened, unique, and value-driven businesses in their local area. 

2. It reduces the dependency on popularity-based ranking systems by giving equal visibility to new and emerging businesses. 

3. It saves users time by providing structured search and filtering options based on location, category, and preferences. 

4. It enables better decision-making by allowing users to compare businesses based on price, value, and services in one platform. 

5. It provides business owners, especially new ones, with a cost-effective way to promote their services without relying heavily on paid advertisements. 

6. It ensures more accurate and updated business information through verified business profiles managed directly by owners. 

7. It enhances user experience by integrating features like location tracking and AI-based assistance for quick access to business information. 

# **Scope** 

The scope of the Khojlo system is to develop a mobile and web-based platform that enables users to discover, compare, and explore local businesses in an efficient and structured manner. The system will focus on highlighting newly opened, unique, and value-driven businesses that are often less visible on existing platforms. It will allow users to search businesses based on categories, location, and personal preferences. The platform will include a discovery feed that showcases emerging businesses to improve their visibility. Users will also be able to compare businesses based on pricing, services, and overall value. 

The system will include verified business profiles where business owners can manage and update their information. These profiles will ensure that users receive accurate and up-to-date details about services, offers, and operating hours. A filtering system will be implemented to help users refine search results efficiently. The project will also integrate a mapping feature to assist users in locating businesses easily. Additionally, a lightweight AI chatbot will be included to answer basic queries related to businesses. 

The scope of the project is limited to local business discovery and comparison within selected categories such as restaurants, cafes, shops, and service providers. It will not include e-commerce transactions or online ordering systems. Payment processing and delivery features are also not part 

of this system. The focus remains on improving visibility, discovery, and information accessibility for both users and business owners. 

# **Modules** 

The Khojlo system is divided into several functional modules that collectively handle user interaction, business management, and discovery of local businesses. Each module performs a specific task and contributes to the overall functionality of the system. 

#### **Module 1: User Authentication and Profile Management** 

This module handles user registration, login, and profile management. It ensures that both customers and business owners can securely access the system. Users can update their personal information and manage their account settings. Authentication ensures secure access to different system features based on user roles. This module also includes a favorites and saved lists feature where users can save businesses for future reference. 

#### **Module 2: Business Registration and Management** 

This module allows business owners to register their businesses on the platform and manage their business profiles. Owners can add details such as business name, category, location, services, contact information, and operating hours. They can also update or modify their business data whenever required. This module includes offers and promotions management, allowing businesses to publish discounts, special deals, and promotional offers. Additionally, basic business analytics such as profile views and user engagement statistics are provided to help business owners understand their reach and visibility. 

#### **Module 3: Business Discovery Feed (New & Trending Businesses)** 

This module focuses on showcasing newly opened and trending businesses to users. It provides a structured feed where users can explore fresh and emerging businesses in their area. The system highlights businesses that are new or gaining attention to improve visibility for small or recently launched businesses. This module also includes push notification functionality that informs users about newly added businesses, trending listings, and promotional offers. The goal of this module is to improve business discovery and user engagement. 

#### **Module 4: Search, Filtering, and Comparison System** 

This module enables users to search for businesses using keywords, categories, and location-based inputs. It includes filtering options that help users refine results according to preferences such as price range, category, and services. The comparison feature allows users to compare multiple businesses based on pricing, services, and overall value. This helps users make better and faster decisions. The module improves accessibility and simplifies the process of finding suitable businesses. 

#### **Module 5: Reviews and Ratings System** 

This module allows users to provide ratings and reviews for businesses based on their experiences. Users can share feedback regarding services, pricing, and overall satisfaction. These reviews help other users make informed decisions when selecting businesses. Business owners can also view customer feedback to improve their services. This module increases trust, transparency, and reliability within the platform. 

#### **Module 6: Maps and Location Integration Module** 

This module integrates mapping and location services into the system. Users can view business locations directly on the map and receive navigation assistance. It helps users discover nearby businesses and improves accessibility. The module uses location-based services to enhance search accuracy and convenience. This feature supports efficient exploration of local businesses. 

#### **Module 7: AI Chatbot Assistance Module (RAG-Based)** 

This module provides an AI-based chatbot that assists users with business-related queries. The chatbot can answer questions about operating hours, available services, promotions, and business details using stored platform information. It uses a Retrieval-Augmented Generation (RAG) approach to provide more accurate and context-based responses. The chatbot improves user interaction by providing instant assistance and reducing the need for manual searching. This module serves as one of the special and intelligent features of the system. 

#### **Module 8: Admin and Moderation System** 

This module is responsible for managing and monitoring overall platform activities. The admin can verify business profiles, monitor user-generated content, and remove spam or fake information from the platform. It also helps maintain the quality and authenticity of business listings and reviews. The moderation functionality ensures that inappropriate or misleading content is controlled effectively. This module improves system reliability, security, and platform trustworthiness. 

#### **Module 9: Chat and Messaging System** 

This module enables direct communication between users and business owners through an integrated messaging system. Users can send inquiries regarding products, services, pricing, availability, or appointments before visiting a business. Business owners can respond to customer messages in real time, allowing one-to-one conversations that improve customer support and engagement. The messaging feature reduces communication barriers, builds trust between users and businesses, and helps customers make informed decisions before visiting or purchasing from a business. 

#### **Module 10: AI Personalization and Recommendation System** 

This module provides personalized business recommendations based on user behavior, preferences, search history, and interactions within the platform. Instead of relying only on keyword-based searches, the system uses AI to deliver context-aware suggestions that match individual user interests and needs. It continuously analyzes user activity to recommend relevant businesses, services, and promotional offers. This intelligent recommendation approach enhances business discovery, improves user experience, and increases user engagement by presenting more meaningful and personalized results. 

# **System Limitations/Constraints** 

The Khojlo system is limited to the availability and accuracy of data provided by business owners, and incomplete or incorrect entries may affect the quality of information shown to users. 

The system is dependent on internet connectivity, as it is a mobile and web-based application, and it cannot function properly in offline mode. 

The platform is initially designed for local business discovery and does not support online transactions, payments, or delivery services. 

The accuracy of AI chatbot responses is limited to the data stored in the system, and it may not handle complex or external queries beyond the provided business information. 

# **Software Process Methodology** 

The proposed system, Khojlo, will be developed using the Object-Oriented Methodology (OOM). This methodology is chosen because it allows the system to be designed in the form of real-world objects such as users, businesses, reviews, and offers, making the system more structured and easier to manage. It supports modular development, where each module can be independently designed, implemented, and tested, which is suitable for a multi-feature system like Khojlo. Object-Oriented Methodology also improves code reusability and scalability, which is important for future enhancements of the platform. This approach aligns well with the use of Flutter for frontend development and FastAPI for backend development, as both support object-oriented design principles. 

# **Tools and Technologies** 

**Table 2Tools and Technologies for Proposed Project** 

|**Tools**|**Version**|**Rationale**|
|---|---|---|
|MS Visual Studio|1.96+|IDE|
|Android Studio|2025.1|Android emulator and|



|||Flutter testing|
|---|---|---|
|Figma|2025|UI/UX design and<br>mockups creation|
|Git|2.54|Version Control|
|GitHub/GitLab|Latest|Repository hosting,<br>CI/CD pipelines, and<br>issue tracking.|
|MS Word|2021|Documentation|
|**Tools**<br>MS Power Point|2021|Presentation|
|**And**<br>**Technologies**<br>Draw.io / Lucidchart|Latest|System architecture<br>diagrams, flowcharts,<br>and ER diagrams.|
|Google Maps API|2026 Edition|Location and mapping<br>services integration|
|**Technology**|**Version**|**Rationale**|
|Flutter|3.24+|Cross-platform mobile<br>and web development<br>framework|
|Dart|3.5+|Programming language<br>for Flutter|
|Python|3.12|Backend development<br>language|
|FastAPI|0.13|Backend web framework<br>for APIs and logic|
|Riverpod|Latest|State management for<br>Flutter apps.|
|PostgreSQL|18.3|Database management<br>system|
|Rest APIs|RESTful (2026<br>standard)|Communication between<br>frontend and backend|
|Postman|Latest|API testing and<br>documentation|
|Swagger|Latest|Automated API<br>documentation.|
|Google Maps SDK|2026 SDK|Location tracking and<br>navigation services|



# **Project Stakeholders and Roles** 

The stakeholders of the project include the project sponsor, development team, supervisor, Final Year Project Committee, end users, and business owners. These stakeholders are involved in the development, supervision, evaluation, and usage of the proposed system. 

**Table 3Project Stakeholders for Proposed Project** 

|**Project**<br>**Sponsor**|COMSATS University Islamabad|
|---|---|
|**Stakeholder**|• Nouman Khan (SP23-BSE-012) – Project Team Member<br>• Sayyam Tahir (SP23-BSE-014) – Project Team Member<br>• Kazim Shauket (SP23-BSE-024) – Project Team Member|
||• Project Supervisor Name: Muhammad Tariq|
||• Final Year Project Committee: Evaluation and assessment of the project|
||• End Users: Users who will use the application for discovering nearby places|
||• Business Owners: Managing and registering business listings within the<br>application|



# **Team Members Individual Tasks/Work Division** 

**Table 4Team Member Work Division for Proposed Project** 

|**Student Name**|**Student Registration Number**|**Responsibility/ Modules**|
|---|---|---|
|Nouman Khan|SP23-BSE-012|Nouman Khan (Module 1 – Module 3)|
|||Module 1: User Authentication and<br>Profile Management<br>Module 2: Business Registration and<br>Management<br>Module 3: Business Discovery Feed (New<br>& Trending Businesses)<br>Module 9: Chat and Messaging System|
|Sayyam Tahir|SP23-BSE-014|Sayyam Tahir (Module 4 – Module 6)|
|||Module 4: Search, Filtering, and<br>Comparison System<br>Module 5: Reviews and Ratings System|



|||Module 6: Maps and Location Integration<br>Module|
|---|---|---|
|Kazim Shauket|SP23-BSE-024|Kazim Shauket (Module 7 – Module 8)|
|||Module 7: AI Chatbot Assistance Module<br>(RAG-Based)|
|||Module 8: Admin and Moderation System|
|||Module 10: AI Personalization and<br>Recommendation System|



# **Data Gathering Approach** 

The requirements and information for the proposed project will be gathered through online research and questionnaires. Existing local discovery and recommendation platforms such as Yelp, TripAdvisor, and Google maps will be analyzed to understand their features, user experience, recommendation systems, and location-based functionalities. Questionnaires will be used to collect feedback from potential users regarding their preferences, difficulties in finding nearby places, and expectations from such a system. The collected information will help in identifying the core requirements and defining the scope of the project. 

# **Concepts** 

#### **Concept-1: RESTful APIs** 

REST APIs will be used to handle communication between the Flutter frontend and FastAPI backend. All business, user, review, and offer data will be exchanged through structured API endpoints using HTTP methods. 

#### **Concept-2: Geolocation and Map Integration** 

Google Maps API and SDK will be integrated to display business locations and support locationbased filtering and navigation. This will involve working with coordinate data and embedding interactive maps within the application. 

#### **Concept-3: AI Chatbot Integration** 

A lightweight AI chatbot will be built to handle basic user queries such as business hours, services, and available deals. This involves understanding intent handling and connecting the chatbot to backend business data. 

#### **Concept-4: Cross-Platform Mobile Development** 

Flutter and Dart will be used to build a single codebase that runs on both Android and web platforms. This will provide experience in widget-based UI design, state management, and API consumption. 

#### **Concept-5: Backend Development with Python and FastAPI** 

FastAPI (Python) will be used to build the backend, manage APIs, handle authentication, and process business logic. This will develop skills in server-side programming, ORM-based database handling, and building scalable web frameworks. 

#### **Concept-6: Database Design and Management** 

PostgreSQL will be used to store and manage all system data including users, businesses, reviews, ratings, and offers. This will involve designing relational schemas and managing entity relationships efficiently. 

#### **Concept-7: UI/UX Design** 

Figma will be used to design the application's interface, including wireframes and mockups for all major modules. This will build skills in user-centered design, prototyping, and translating designs into Flutter widgets. 

#### **Concept-8: Software Documentation** 

The project requires writing a formal scope document, feasibility report, SRS, and technical documentation following academic standards. This develops skills in professional technical writing, requirement specification, and structured reporting. 

#### **Concept-9: Agile Software Development** 

The project will follow the Agile Software Development methodology using the Scrum framework. Development will be carried out in iterative sprints where tasks and modules will be divided among team members according to project requirements. Regular team meetings and progress reviews will help track development and resolve issues efficiently. Scrum will support collaborative development, continuous improvement, and flexible management of changing requirements. This approach will provide practical experience in sprint planning, teamwork, task management, and iterative software development practices. 

#### **Concept-10: Software Testing** 

The proposed system will undergo different levels of testing to ensure correctness, usability, and proper system functionality. Unit testing will be performed on backend APIs and individual 

functions using the FastAPI testing framework and PyTest. Integration testing will be conducted to verify proper communication between the Flutter frontend and FastAPI backend APIs. System testing will be performed to evaluate the overall workflow and functionality of the complete application. User Acceptance Testing (UAT) will also be conducted to ensure that the system meets user requirements and provides a satisfactory user experience. Tools such as Postman will be used for API testing, while Flutter’s built-in testing support will be used for frontend testing. 

||T<br>s<br>||||||a<br>|
|---|---|---|---|---|---|---|---|
||a<br><br>||o<br>|s<br>||(n<br>|e<br>|
|i<br>|n<br>|n<br>||so<br>|e<br>||i<br>|
|E<br><br>|ccd<br><br>|||||||
|e<br>|sn<br><br>|||||.<br><br><br>||
||||<br>|2<br>||ce<br><br>|S<br><br><br>|e<br><br>|
|re|n||||||n<br>|
||||||s<br><br>|e<br><br><br>|a<br><br>|
||n<br><br>|||||||
||n<br><br>|||||||
|=<br>|Winans<br><br>||<br>|<br>|<br>|<br>e<br>|<br> <br>|
|<br><br>|<br><br>e<br><br>||<br><br><br>|<br><br> <br>|<br><br> <br>|<br><br> <br>|<br><br> <br>|
|<br>|Wiktgemiste<br>wa<br>||<br>|<br><br> <br>|<br><br> <br>|<br>e<br> <br>|<br><br> <br>|
|<br>8S|<br>Si|n|<br>wets|<br>|<br>|c<br>e|a<br>e|





<!-- Start of picture text -->
Te<br>a os(ne<br>es a<br>i nn soe i<br>Eccde<br>no.<br>esne | 2 oece Se<br>rens<br>ce Sn<br>2<br>se a<br>no<br>no<br>es Se Sie<br>8 een oi<br>= Winans vn nem<br>eC<br>2S wate2 sae |<br>Wiktgemiste<br>8S Sinica<br>wets eee<br><!-- End of picture text -->



<!-- Start of picture text -->
Good night J<br>Discover your<br>city'se 1  best spots<br>234 amazing places waiting for you<br>Q ; A<br>Me<br>Browse Categories All ><br>~<br>VEY ine) um<br>Restaurants Cafés Bars Parks Hotels Shopping<br>Near You «tive See all ><br>P<br><!-- End of picture text -->



<!-- Start of picture text -->
KHOJLOTrendingP Places 2= Trendin7<br>@ Restaurants Cafés Bars Parks<br>8 places found 2 saved<br>Hot 4 a<br>w<br>L, = :<br>aei 5 se: as ~~ 2" re<br>eAR & LOONGEin ig ign’ . leiF SF aa ° :<br>Sky Eleven Rooftop<br>Stunning 360° city views with craft cocktails and live DJ sets<br>Home Explore Map Chat Business<br><!-- End of picture text -->



<!-- Start of picture text -->
Near You Live Seeall ><br>Nearest _ g 4<br>Ly<br>oe Soda<br>4 l<br>F = >- y eg i<br>DESSERTS SPECIALTY COFFEE JAPA<br>Scoops & Swirls Brew & Bloom Rame<br>w44 © 0.2 km ww 49 © 0.3 km w 4<br>Trending Today 5 See all ><br>ITALIAN RESTAURANT.<br>Forno Italiano<br>Wood-fired Neapolitan pizzas & handmade pasta...<br>Ww 4.7741) ©11km<br>ura eeneen<br><!-- End of picture text -->



<!-- Start of picture text -->
Btz DeKHOJLOKai is here  Alto hel 5<br>@ Hi! I'm Kai «@, your KHOJLO discovery<br>assistant.<br>Tell me what you're looking for — restaurants,<br>cafés, hidden gems, nightlife — and I'll find<br>the best spots near you! “)<br>22:15<br>> Best restaurants near me > Top cafes > Trending thi<br>W) Ask for places..<br>Home Explore Map Chat Business<br><!-- End of picture text -->

# **Conclusion** 

In conclusion, this project aims to provide a practical and user-friendly platform that helps users discover new businesses, trending places, and valuable local services more efficiently. The proposed system will bridge the gap between customers and businesses by offering locationbased recommendations, business insights, and updated market information in a single application. By focusing on usability, accessibility, and modern technologies, the project has the potential to improve business visibility while also enhancing the overall user experience. Furthermore, the system can support local economic growth by promoting small and newly established businesses to a wider audience. Overall, the project presents an innovative and feasible solution that addresses real-world problems in the local business discovery domain. 

# **References** 

1. Sommerville, I. (2016). _Software Engineering_ (10th ed.). Pearson Education. 

2. Dix, A., Finlay, J., Abowd, G. D., & Beale, R. (2004). _Human-Computer Interaction_ (3rd ed.). Pearson Education. 

3. Flutter Official Documentation 

4. FastAPI Documentation 

5. <u>Firebase Documentation</u> 

6. <u>Google Maps Platform Documentation</u> 

7. <u>PostgreSQL Official Documentation</u> 

8. <u>Figma Official Website</u> 

# **Plagiarism Report** 

Attach the Plagiarism report of your project scope document from library staff of turnitin tool <u>(http://turnitin.com</u> 

19 

