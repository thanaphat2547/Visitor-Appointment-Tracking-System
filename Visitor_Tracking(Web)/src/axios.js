import axios from "axios";

const instance = axios.create({
  baseURL: "http://192.168.1.33:3001",
  timeout: 10000,  // กัน request ค้างเกิน 10 วิ
});

instance.interceptors.request.use((config) => {
  const credentials = localStorage.getItem("auth"); // ดึงจาก localStorage
  if (credentials) {
    config.headers.Authorization = `Basic ${credentials}`;
  }
  return config;
},
  (error) => Promise.reject(error)
);

instance.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response) {
      const status = error.response.status;

      if (status === 401) {
        // ไม่ได้ login / token หมดอายุ
        localStorage.removeItem("auth");
        localStorage.removeItem("user");

        // redirect ไปหน้า login
        window.location.href = "/";
      } else if (status === 403) {
        console.error("403 Forbidden: ไม่มีสิทธิ์เข้าถึง API นี้");
      }
    }
    return Promise.reject(error);
  }
);

export default instance;
