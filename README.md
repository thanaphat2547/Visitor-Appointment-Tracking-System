## 🏢 Visitor Appointment Tracking System
<img width="1920" height="954" alt="651688 ProjectPresent" src="https://github.com/user-attachments/assets/adb53e87-ed6d-4480-8d2c-a1220da5e690" />

### 📖 Overview (ภาพรวมของระบบ)
โปรเจกต์นี้พัฒนาด้วย **Vue.js, Node.js, SQL Server** และ **Leaflet.js** มีจุดประสงค์เพื่อเพิ่มประสิทธิภาพใน **การบริหารจัดการนัดหมาย** และ **ติดตามตำแหน่งบนแผนที่** ภายในพื้นที่อาคาร  
โดยนำเสนอในรูปแบบโปรแกรมประยุกต์บนเว็บ (Web Application) และแอปพลิเคชันบนโทรศัพท์เคลื่อนที่ (Mobile Application)  
ระบบนี้ประยุกต์ใช้เทคโนโลยี **Bluetooth Beacon** ทำงานร่วมกับระบบแจ้งเตือน **Firebase (FCM)** ซึ่งเจ้าหน้าที่จะได้รับการแจ้งเตือนทันทีเมื่อผู้มาติดต่อเดินทางมาถึง และสามารถตรวจสอบพิกัดได้อย่างแม่นยำผ่านแผนที่จำลอง

---

### ✨ Key Features (ฟีเจอร์การทำงานหลัก)
- **🌐 Web Application:** ระบบจัดการสำหรับเจ้าหน้าที่และผู้ดูแลระบบ (Admin) พร้อมแดชบอร์ดแสดงผลแผนที่พิกัดภายในอาคาร (Indoor Localization) ด้วย Leaflet.js
- **📱 Mobile Application:** ระบบสำหรับผู้มาติดต่อและเจ้าหน้าที่ ใช้ในการลงทะเบียนนัดหมาย ตรวจสอบสถานะ และแสดงผลการแจ้งเตือน
- **📍 Real-Time Tracking & Beacon:** ประยุกต์ใช้ฮาร์ดแวร์ Bluetooth Beacon เพื่อระบุตำแหน่งของผู้มาติดต่อได้อย่างแม่นยำ
- **🔔 Push Notifications:** เชื่อมต่อระบบแจ้งเตือนข้ามแพลตฟอร์มแบบเรียลไทม์ด้วย Firebase Cloud Messaging (FCM) 

### 💻 Tech Stack (เทคโนโลยีที่ใช้พัฒนา)
- **Frontend (Web / Mobile):** Vue.js, HTML5, CSS3, JavaScript
- **Backend:** Node.js (Express), RESTful API
- **Database:** SQL Server
- **Tools & Services:** Firebase (FCM), Leaflet.js, Insomnia, DBeaver

### 📁 Repository Structure (โครงสร้างโปรเจกต์)
โปรเจกต์นี้ถูกจัดเก็บในรูปแบบ **Monorepo** เพื่อให้ง่ายต่อการพัฒนาแบบ Full-Stack โดยแบ่งโครงสร้างโฟลเดอร์ดังนี้:
- 📂 `Visitor_Tracking(Backend)/` — Source code สำหรับระบบหลังบ้าน (Node.js API) และการเชื่อมต่อฐานข้อมูล
- 📂 `Visitor_Tracking(Web)/` — Source code สำหรับโปรแกรมประยุกต์บนเว็บ (Frontend)
- 📂 `Visitor_Tracking(Mobile)/` — Source code สำหรับแอปพลิเคชันบนโทรศัพท์เคลื่อนที่
