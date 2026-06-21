<template>
  <a-spin :spinning="isLoading" tip="กำลังโหลดข้อมูล...">
  <div class="container-fluid my-4">
    <!-- Toolbar -->
    <div class="toolbar">
      <!-- Search -->
      <a-input
        class="search-input"
        v-model:value="searchValue"
        placeholder="ค้นหาผู้มาติดต่อ..."
        enter-button="ค้นหา"
        size="large"
      />

      <!-- Add button -->
      <a-button type="primary" class="btn-Add" @click="addemp">
        <i class="bi bi-plus-circle me-1"></i> เพิ่มผู้มาติดต่อ
      </a-button>
    </div>

    <!-- ตาราง -->
    <div class="card-table p-3 rounded shadow-sm">
      <a-table
        bordered
        :data-source="filteredData"
        :columns="columns"
        rowKey="vis_id"
        :pagination="pagination"
        :scroll="{ x: 400 }"
        @change="handleTableChange"
        class="styled-table"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'creator_name'">
            <span v-if="record.creator_name">
              <user-outlined style="margin-right: 4px; color: #1890ff;" />
              {{ record.creator_name }}
            </span>
            <span v-else style="color: #ccc;">- ไม่พบข้อมูล -</span>
          </template>

          <template v-else-if="column.key !== 'action'">
            {{ record[column.dataIndex] }}
          </template>
  
          <template v-else>
            <edit-outlined class="editable-cell-icon" @click="editemp(record)" />
            <a-divider type="vertical" />
            <a-popconfirm title="ยืนยันการลบ?" ok-text="ยืนยัน" cancel-text="ยกเลิก" @confirm="deleteRow(record.vis_id)">
              <delete-outlined class="editable-cell-icon-close" />
            </a-popconfirm>
          </template>
        </template>
      </a-table>
    </div>

    <!-- Modal Add/Edit -->
    <a-modal
      :title="isEditing ? 'แก้ไขข้อมูลผู้มาติดต่อ' : 'เพิ่มผู้มาติดต่อใหม่'"
      v-model:open="isModalVisible"
      @ok="isEditing ? saveEdit() : saveAdd()"
      @cancel="closeModal"
      ok-text="บันทึก"
      cancel-text="ยกเลิก"
      :style="{ top: '80px' }"
      :centered="false"
    >
      <a-form 
        :key="formKey"
        layout="vertical"
        :model="formData"
        :rules="rules"
        ref="forRef"
        :requiredMark="false"
      >
        <a-form-item label="ชื่อ" name="vis_firstname">
          <a-input 
            v-model:value="formData.vis_firstname"
            :maxlength="32" 
            placeholder="กรอกชื่อ"
            @keydown="blockSpecialCharacters"
            @paste="cleanNamePaste('vis_firstname')"
          />
        </a-form-item>
        <a-form-item label="นามสกุล" name="vis_lastname">
          <a-input 
            v-model:value="formData.vis_lastname"
            :maxlength="32" 
            placeholder="กรอกนามสกุล" 
            @keydown="blockSpecialCharacters"  
            @paste="cleanNamePaste('vis_lastname')" 
          />
        </a-form-item>
        <a-form-item label="อีเมล" name="vis_email">
          <a-input 
            v-model:value="formData.vis_email"
            :maxlength="32" 
            placeholder="กรอกอีเมล" 
            @keydown="blockEmail"
          />
        </a-form-item>
        <a-form-item label="เบอร์โทรศัพท์" name="vis_phone">
          <a-input 
            v-model:value="formData.vis_phone" 
            placeholder="กรอกเบอร์โทรศัพท์" 
            :maxlength="12"
            @keydown="blockNonNumeric"
            @input="formatPhoneNumber" 
          />
        </a-form-item>
        
        <a-form-item label="ผู้ลงทะเบียนข้อมูล" name="creator_name">
          <a-input 
            :value="isEditing ? formData.creator_name : currentUserName" 
            disabled 
            style="color: #000; background-color: #f5f5f5;"
          >
            <template #prefix>
              <user-outlined />
            </template>
          </a-input>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
  </a-spin>
</template>

<script setup>
import { ref, reactive, computed, onMounted, nextTick, } from "vue"
import axios from '@/axios';
import { message } from "ant-design-vue"
import { EditOutlined, DeleteOutlined } from "@ant-design/icons-vue"

// state
const data = ref([])
const searchValue = ref("")
const isModalVisible = ref(false)
const isEditing = ref(false)
const forRef = ref(null);
const formKey = ref(0)
const isLoading = ref(true)
const currentUserName = ref("");

const auth = localStorage.getItem("auth");

const rules = {
  vis_firstname: [
    { required: true, message: "กรุณากรอก ชื่อ" },
    { min: 1, max: 32 }
  ],
  vis_lastname: [
    { required: true, message: "กรุณากรอก นามสกุล" },
    { min: 1, max: 32 }
  ],
  vis_email: [
  { required: true, message: "กรุณากรอก อีเมล" },
  { type: "email", message: "กรุณากรอกอีเมลให้ถูกต้อง เช่น name@gmail.com" }
  ],
  vis_phone: [
    { required: true, message: "กรุณากรอกเบอร์โทรศัพท์" },
    { pattern: /^\d{3}-\d{3}-\d{4}$/, message: "เบอร์โทรต้องเป็นตัวเลข 10 หลัก" }
  ]
};

const setCurrentUser = () => {
  const savedProfile = JSON.parse(localStorage.getItem('profile') || '{}');
  if (savedProfile.emp_firstname) {
    currentUserName.value = `${savedProfile.emp_firstname} ${savedProfile.emp_lastname}`;
  }
};

const formData = reactive({
  vis_id: "",
  vis_firstname: "",
  vis_lastname: "",
  vis_email: "",
  vis_phone: "",
  creator_name: ""
})

// columns
const columns = [
  { title: "ชื่อ", dataIndex: "vis_firstname", key: "vis_firstname" },
  { title: "นามสกุล", dataIndex: "vis_lastname", key: "vis_lastname" },
  { title: "อีเมล", dataIndex: "vis_email", key: "vis_email" },
  { title: "เบอร์โทรศัพท์", dataIndex: "vis_phone", key: "vis_phone" },
  { 
    title: "ลงทะเบียนโดย", 
    dataIndex: "creator_name", 
    key: "creator_name",
    width: 180 
  },
  { title: "การจัดการ", key: "action", width: 100 }
]

// pagination
const pagination = ref({
  current: 1,
  pageSize: 5,
  showSizeChanger: true,
  pageSizeOptions: ["5", "10", "20"]
})

// กรองชื่อ ตอนพิมให้กรอกได้แค่ ภาษาอังกฤษกับไทย
const blockSpecialCharacters = (e) => {
  const allowed = /[ก-ฮะ-์a-zA-Z\s]/
  const controlKeys = [
    "Backspace", "Delete", "ArrowLeft", "ArrowRight",
    "Tab", "Enter", "Escape", "Home", "End"
  ]

  if (!allowed.test(e.key) && !controlKeys.includes(e.key)) {
    e.preventDefault()
    return
  }
}

// กรองชื่อ ตอนคัดลอกมาวางให้กรอกได้แค่ ภาษาอังกฤษกับไทย
const cleanNamePaste = (field) => (e) => {
  e.preventDefault();
  const pasted = e.clipboardData.getData("text") || "";
  const clean = pasted.replace(/[^ก-ฮะ-์a-zA-Z\s]/g, "");
  formData[field] = (formData[field] + clean).slice(0, 32);
};

// ฟิลเตอร์อีเมล: อนุญาตเฉพาะ a-z, 0-9, .
const blockEmail = (e) => {
  const allowed = /[a-zA-Z0-9.@]/; // เฉพาะ a-z, 0-9, .
  const controlKeys = [
    "Backspace", "Delete", "ArrowLeft", "ArrowRight",
    "Tab", "Enter", "Escape", "Home", "End"
  ];
  if (!allowed.test(e.key) && !controlKeys.includes(e.key)) {
    e.preventDefault();
  }
};

// ป้องกันพิมพ์อักษรนอกเหนือจาก A-Z, a-z, 0-9 สำหรับ password
const blockPassword = (e) => {
  const allowed = /[a-zA-Z0-9!@#$%^&*()\-_=+?.,]/;
  const controlKeys = [
    "Backspace", "Delete", "ArrowLeft", "ArrowRight",
    "Tab", "Enter", "Escape", "Home", "End"
  ];
  if (!allowed.test(e.key) && !controlKeys.includes(e.key)) {
    e.preventDefault();
  }
};

// กรองให้กรอกเฉพาะตัวเลข
const blockNonNumeric = (e) => {
  const allowed = /[0-9]/; // อนุญาตแค่ตัวเลข
  const controlKeys = [
    "Backspace", "Delete", "ArrowLeft", "ArrowRight",
    "Tab", "Enter", "Escape", "Home", "End"
  ];

  if (!allowed.test(e.key) && !controlKeys.includes(e.key)) {
    e.preventDefault();
    return;
  }
};

// กรอกเบอร์โทร
const formatPhoneNumber = () => {
  // ลบอักขระที่ไม่ใช่ตัวเลขออก
  let digits = formData.vis_phone.replace(/\D/g, "");

  // จำกัดความยาวไม่เกิน 10 หลัก
  digits = digits.slice(0, 10);

  // จัดรูปแบบ 3-3-4
  if (digits.length > 6) {
    formData.vis_phone =
      digits.slice(0, 3) + "-" + digits.slice(3, 6) + "-" + digits.slice(6);
  } else if (digits.length > 3) {
    formData.vis_phone =
      digits.slice(0, 3) + "-" + digits.slice(3);
  } else {
    formData.vis_phone = digits;
  }
};

// filter Search
const filteredData = computed(() => {
  if (!searchValue.value) return data.value;
  const searchParts = searchValue.value.toLowerCase().split(/\s+/);
  return data.value.filter((item) => {
    const itemText = Object.values(item).join(" ").toLowerCase();
    return searchParts.every(part => itemText.includes(part));
  });
});


// handle pagination change
const handleTableChange = (pag) => {
  pagination.value = { ...pagination.value, ...pag }
}

// โหลดข้อมูล vis
const fetchvis = async () => {
  try {
    const res = await axios.get("/visitor/show_visitor", {
  headers: { Authorization: `Basic ${auth}` },
});

    if (Array.isArray(res.data)) {
      data.value = res.data
    } else if (Array.isArray(res.data.data)) {
      data.value = res.data.data
    } else {
      data.value = []
    }
  } catch (error) {
    message.error("โหลดข้อมูลผู้มาติดต่อไม่สำเร็จ")
    data.value = []
  }
}

// modal control
const addemp = async () => {
  formKey.value++
  Object.assign(formData, {
    vis_id: "",
    vis_firstname: "",
    vis_lastname: "",
    vis_email: "",
    emp_username: "",
    emp_password: "",
    vis_phone: "",
    creator_name: currentUserName.value
  })
  isEditing.value = false
  isModalVisible.value = true
}

const editemp = async (record) => {
  formKey.value++
  
  Object.assign(formData, {
    ...record,
    creator_name: record.creator_name || "- ไม่พบข้อมูลผู้ลงทะเบียน -"
  })

  isEditing.value = true
  isModalVisible.value = true
}

const closeModal = async () => {
  isModalVisible.value = false
  await nextTick()
  forRef.value?.resetFields()
  forRef.value?.clearValidate()
}

// save add
const saveAdd = async () => {
  try {
    await forRef.value.validate();
    
    // ดึงโปรไฟล์ผู้ใช้งานที่ล็อกอินอยู่จาก localStorage
    const savedProfile = JSON.parse(localStorage.getItem('profile') || '{}');
    
    
    const payload = {
      ...formData,
      created_by: savedProfile.emp_id 
    };

    const res = await axios.put("/visitor/add_visitor", payload, {
        headers: { Authorization: `Basic ${auth}` } 
    });
    
    message.success(res.data.message || "บันทึกสำเร็จ");
    await fetchvis();
    closeModal();
  } catch (error) {
    message.error(error.response?.data?.message || "บันทึกไม่สำเร็จ");
  }
};

// save edit
const saveEdit = async () => {
  try {
    await forRef.value.validate();
    const res = await axios.patch("/visitor/edit_visitor", formData)
    message.success(res.data.message || "แก้ไขสำเร็จ")
    await fetchvis()
    closeModal()
  } catch (error) {
    message.error(error.response?.data?.message || "อัปเดตไม่สำเร็จ")
  }
}

// delete
const deleteRow = async (vis_id) => {
      try {
        const res = await axios.patch("/visitor/delete_visitor", { vis_id })
        message.success(res.data.message || "ลบสำเร็จ")
        await fetchvis()
      } catch (error) {
        message.error(error.response?.data?.message || "ลบไม่สำเร็จ")
      }
    }

// โหลดข้อมูลตอนเข้า
onMounted(async () => {
  isLoading.value = true
  setCurrentUser();           
  await fetchvis();          
  isLoading.value = false;         
});

</script>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Prompt:wght@400;500;600;700&display=swap');

.container-fluid { font-family: 'Prompt', sans-serif; }

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  flex-wrap: wrap;
  gap: 12px;
}

.search-input { width: 300px; }

.btn-Add {
  background: linear-gradient(135deg, #00C896, #00a877) !important;
  border-color: transparent !important;
  color: white !important;
  height: 38px !important;
  padding: 0 18px !important;
  border-radius: 10px !important;
  font-weight: 600 !important;
  display: flex;
  align-items: center;
  gap: 6px;
  box-shadow: 0 3px 10px rgba(0,200,150,0.3) !important;
  transition: all 0.2s ease !important;
}

.btn-Add:hover {
  transform: translateY(-1px) !important;
  box-shadow: 0 5px 16px rgba(0,200,150,0.4) !important;
}

.card-table {
  background-color: white;
  border-radius: 8px;
  overflow: hidden;
}

/* หัวตารางโค้งด้านบน */
:deep(.ant-table-thead > tr:first-child > th:first-child) {
  border-top-left-radius: 8px !important;
}
:deep(.ant-table-thead > tr:first-child > th:last-child) {
  border-top-right-radius: 8px !important;
}

/* มุมล่างซ้าย-ขวา */
:deep(.ant-table-container) {
  border-radius: 8px !important;
  overflow: hidden !important;
}
:deep(.ant-table-tbody > tr:last-child > td:first-child) {
  border-bottom-left-radius: 8px !important;
}
:deep(.ant-table-tbody > tr:last-child > td:last-child) {
  border-bottom-right-radius: 8px !important;
}

:deep(.ant-table-tbody > tr:hover) {
  background-color: #f1f8f1 !important;
}
:deep(.ant-pagination-item a) {
  color: rgb(0, 0, 0) !important;
}
:deep(.ant-pagination-item-active) {
  border: 1px solid rgb(0, 0, 0) !important;
  border-radius: 4px;
  background: white !important;
}
:deep(.ant-pagination-item-active a) {
  color: rgb(0, 0, 0) !important;
  font-weight: bold;
}
:deep(.ant-pagination-prev button),
:deep(.ant-pagination-next button) {
  background: transparent !important;
  border: none !important;
  color: rgb(0, 0, 0) !important;
  box-shadow: none !important;
}

.editable-cell-icon {
  color: #3b82f6;
  cursor: pointer;
  font-size: 16px;
  transition: all 0.2s;
}
.editable-cell-icon:hover { color: #2563eb; transform: scale(1.15); }

.editable-cell-icon-close {
  color: #ef4444;
  cursor: pointer;
  font-size: 16px;
  transition: all 0.2s;
}
.editable-cell-icon-close:hover { color: #dc2626; transform: scale(1.15); }

@media screen and (max-width: 1024px) {
  .toolbar {
    flex-wrap: wrap;
    gap: 12px;
  }

  .btn-Add {
    font-size: 15px;
    height: 38px;
    padding: 0 12px;
  }

  .card-table {
    padding: 16px;
  }

  .styled-table {
    font-size: 14px;
  }
}

</style>