<template>
  <div class="login-container">
    <div class="login-box">
      <div class="login-header">
        <img src="@/assets/โลโก้.png" alt="Logo" class="logo-login"/>
        <h1>ระบบติดตามการนัดหมายผู้มาติดต่อ</h1>
        <h2>Visitor Appointment Tracking System</h2>
      </div>
      <a-form 
        layout="vertical" 
        :model="form"
        :requiredMark="false" 
        @finish="handleLogin"
      >
        <a-form-item label="ชื่อผู้ใช้" name="emp_username" :rules="[{ required: true, message: 'กรุณากรอกชื่อผู้ใช้' }]">
          <a-input v-model:value="form.emp_username" placeholder="กรอกชื่อผู้ใช้" size="large" class="custom-input">
            <template #prefix>
              <UserOutlined style="color: rgba(0,0,0,.25)" />
            </template>
          </a-input>
        </a-form-item>

        <a-form-item label="รหัสผ่าน" name="emp_password" :rules="[{ required: true, message: 'กรุณากรอกรหัสผ่าน' }]">
          <a-input-password v-model:value="form.emp_password" placeholder="กรอกรหัสผ่าน" size="large" class="custom-input">
            <template #prefix>
              <LockOutlined style="color: rgba(0,0,0,.25)" />
            </template>
          </a-input-password>
        </a-form-item>

        <a-form-item class="submit-item">
          <a-button type="primary" html-type="submit" size="large" block :loading="isLoggingIn" class="btn-green">
            เข้าสู่ระบบ
          </a-button>
        </a-form-item>
      </a-form>
    </div>
  </div>
</template>

<script setup>
import { reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { message } from "ant-design-vue";
import { UserOutlined, LockOutlined } from '@ant-design/icons-vue';
import axios from "@/axios";

// นำเข้าฟังก์ชันจาก Firebase
import { getAuth, signInAnonymously } from "firebase/auth";
import { getMessaging, getToken } from "firebase/messaging";
import { messaging, auth } from "@/firebase";

// กำหนด config ให้ message
message.config({
  maxCount: 1,
  duration: 3
});

const router = useRouter();
const form = reactive({ emp_username: "", emp_password: "" });
const isLoggingIn = ref(false);

// ฟังก์ชันแปลง UTF-8 เป็น Base64
function utf8ToB64(str) {
  return btoa(unescape(encodeURIComponent(str)));
}

// ฟังก์ชันแสดง error message
const showErrorMessage = (msg) => {
  message.destroy();
  setTimeout(() => {
    message.error({
      content: msg,
      key: 'login-error',
      duration: 3
    });
  }, 150);
};

const handleLogin = async () => {
  isLoggingIn.value = true;
  localStorage.clear();
  
  try {
    const credentials = utf8ToB64(`${form.emp_username}:${form.emp_password}`);

    const response = await axios.post("/employee/login", {}, {
      headers: { Authorization: `Basic ${credentials}` },
      validateStatus: (status) => status < 500
    });

    const { success, role_id, emp_id, message: msg } = response.data;

    if (success === true) {
      const validEmpId = emp_id || response.data.emp_id;

      localStorage.setItem("auth", credentials);
      localStorage.setItem("username", form.emp_username);
      localStorage.setItem("role_id", role_id);
      localStorage.setItem("user_id", validEmpId);

      const userObj = { role_id: role_id, emp_id: validEmpId };
      localStorage.setItem("user", JSON.stringify(userObj));
      
      if (Number(role_id) === 1) {
        console.log("👮 Officer detected: Requesting FCM Token...");
        await saveFcmToken(validEmpId);
      } else {
        console.log("👤 Admin/Other detected: Skipping FCM Token registration.");
      }
      
      try {
        const profilePayload = { emp_id: validEmpId };
        const profileRes = await axios.post("/employee/profile", profilePayload, {
          headers: { Authorization: `Basic ${credentials}` }
        });

        if (profileRes.data && profileRes.data.data) {
          localStorage.setItem("profile", JSON.stringify(profileRes.data.data));
        }
      } catch (e) {
        console.error("❌ ดึงโปรไฟล์ล้มเหลว:", e.message);
      }

      message.success(msg || "เข้าสู่ระบบสำเร็จ");
      
      setTimeout(() => {
        const role = Number(role_id);
        if (role === 0) router.replace("/admin/dashboard");
        else if (role === 1) router.replace("/map");
        else router.replace("/");
      }, 500);

    } else {
      showErrorMessage(msg || "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง");
    }
  } catch (error) {
    console.error("System Error:", error);
    showErrorMessage("เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์");
  } finally {
    isLoggingIn.value = false;
  }
};

async function saveFcmToken(user_id) {
  try {
    const userCredential = await signInAnonymously(auth);
    console.log('👤 Firebase Login Success:', userCredential.user.uid);

    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      console.warn('🚫 User denied notification permission');
      return;
    }

    const fcm_token = await getToken(messaging, {
      vapidKey: "BOQDxZ2nQ28XV8JQHYQBv0DRUKTJjXjNc23d1oQtHVt13pVZuIdO4Zdc46aVA7E6v2-SIeTgiI2llV6kFoxta7s"
    });

    if (fcm_token) {
      console.log('✅ FCM Token Received:', fcm_token);

      const roleName = 'officer'; 

      await axios.post("/notification/save-fcm-token", {
        user_id: user_id,
        fcm_token: fcm_token,
        role: roleName,
      });
      
      console.log("💾 FCM Token saved to Database!");
    } else {
      console.warn("⚠️ No FCM Token available");
    }
  } catch (err) {
    console.error('❌ Error in saveFcmToken:', err);
  }
}
</script>

<style scoped>

.login-container {
  height: 100vh;
  position: relative;
  display: flex;
  justify-content: center;
  align-items: center;
  background-image:
    url('../assets/พื้นหลัง.png');
  background-size: cover;
  background-position: center;
  font-family: 'Prompt', sans-serif;
  padding: 20px;
  overflow-y: auto;
  flex-direction: column;
}

.login-box {
  width: 100%;
  margin-left: 50%;
  max-width: 500px;
  padding: 40px 32px;
  background: #ffffff;
  border-radius: 12px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
}

.login-header {
  text-align: center;
  margin-bottom: 32px;
}

.logo-login {
  height: 100px;
  margin-bottom: 15px;
}

h1 {
  font-size: 25px;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 4px;
}

h2 {
  font-size: 14px;
  font-weight: 400;
  color: #6b7280;
  margin-bottom: 0;
}

.custom-input {
  border-radius: 8px;
  height: 48px;
}

::v-deep(.ant-input-prefix) {
  margin-right: 8px;
}

::v-deep(.ant-form-item-label > label) {
  color: #374151;
  font-size: 14px;
  font-weight: 500;
  font-family: 'Prompt', sans-serif !important;
}

.btn-green {
  background-color: #00b96b; 
  border-color: #00b96b;
  border-radius: 8px;
  height: 48px;
  font-size: 16px;
  font-weight: 500;
  box-shadow: none;
}

.btn-green:hover,
.btn-green:focus {
  background-color: #00a05a;
  border-color: #00a05a;
}

.submit-item {
  margin-top: 30px;
  margin-bottom: 0;
}

@media screen and (max-width: 1024px) and (orientation: portrait) {
  .login-box {
    max-width: 450px;
    padding: 32px;
  }

  h1 {
    font-size: 30px;
  }

  .logo-login {
    height: 90px;
  }

  ::v-deep(.ant-input-lg) {
    height: 55px;
    font-size: 20px;
    padding: 14px 15px;
  }

  ::v-deep(.ant-input-password .ant-input) {
  height: 45px;
  font-size: 20px;
  padding: 12px 5px;
  }

  ::v-deep(.ant-form-item-label > label) {
    font-size: 22px;
  }

  ::v-deep(.ant-btn-lg) {
    height: 56px;
    font-size: 20px;
  }
}

@media screen and (max-width: 1370px) and (orientation: landscape) {
  .login-box {
    max-width: 420px;
    padding: 30px;
  }

  h1 {
    font-size: 28px;
  }

  .logo-login {
    height: 80px;
  }

  ::v-deep(.ant-input-lg) {
    height: 50px;
    font-size: 18px;
    padding: 14px 15px;
  }

  ::v-deep(.ant-input-password .ant-input) {
  height: 35px;
  font-size: 18px;
  padding: 12px 5px;
  }

  ::v-deep(.ant-form-item-label > label) {
    font-size: 20px;
  }

  ::v-deep(.ant-btn-lg) {
    height: 50px;
    font-size: 18px;
  }
}

</style>