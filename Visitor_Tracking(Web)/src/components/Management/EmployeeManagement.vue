<template>
  <a-spin :spinning="isLoading" tip="กำลังโหลดข้อมูล...">
  <div class="container-fluid my-4">
    <!-- Toolbar -->
    <div class="toolbar">
      <!-- Search -->
      <a-input
        class="search-input"
        v-model:value="searchValue"
        placeholder="ค้นหาพนักงาน..."
        enter-button="ค้นหา"
        size="large"
      />

      <!-- Add button -->
      <a-button type="primary" class="btn-Add" @click="addemp">
        <i class="bi bi-plus-circle me-1"></i> เพิ่มพนักงาน
      </a-button>
    </div>

    <!-- ตาราง -->
    <div class="card-table p-3 rounded shadow-sm">
      <a-table
        bordered
        :data-source="filteredData"
        :columns="columns"
        rowKey="emp_id"
        :pagination="pagination"
        :scroll="{ x: 400 }"
        @change="handleTableChange"
        class="styled-table"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'action'">
            <edit-outlined class="editable-cell-icon" @click="editemp(record)" />
            <a-divider type="vertical" />
            <a-popconfirm title="ยืนยันการลบพนักงานคนนี้หรือไม่?" ok-text="ยืนยัน" cancel-text="ยกเลิก" @confirm="deleteRow(record.emp_id)">
              <delete-outlined class="editable-cell-icon-close" />
            </a-popconfirm>
          </template>

          <template v-else>
            {{ record[column.dataIndex] || '-' }} 
          </template>
        </template>
      </a-table>
    </div>

    <!-- Modal Add/Edit -->
    <a-modal
      :title="isEditing ? 'แก้ไขข้อมูลพนักงาน' : 'เพิ่มพนักงานใหม่'"
      v-model:open="isModalVisible"
      @ok="isEditing ? saveEdit() : saveAdd()"
      @cancel="closeModal"
      ok-text="บันทึก"
      cancel-text="ยกเลิก"
      :style="{ top: '90px' }"
      :bodyStyle="{ maxHeight: '60vh', overflowY: 'auto' }"
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
        <a-form-item label="ชื่อ" name="emp_firstname">
          <a-input 
            v-model:value="formData.emp_firstname"
            :maxlength="32" 
            placeholder="กรอกชื่อ"
            @keydown="blockSpecialCharacters"
            @paste="cleanNamePaste('emp_firstname')"
          />
        </a-form-item>
        <a-form-item label="นามสกุล" name="emp_lastname">
          <a-input 
            v-model:value="formData.emp_lastname"
            :maxlength="32" 
            placeholder="กรอกนามสกุล" 
            @keydown="blockSpecialCharacters"  
            @paste="cleanNamePaste('emp_lastname')" 
          />
        </a-form-item>
        <a-form-item label="อีเมล" name="emp_email">
          <a-input 
            v-model:value="formData.emp_email"
            :maxlength="32" 
            placeholder="กรอกอีเมล" 
            @keydown="blockEmail"
          />
        </a-form-item>
        <a-form-item label="ชื่อบัญชี" name="emp_username">
          <a-input 
            v-model:value="formData.emp_username"
            :maxlength="32" 
            placeholder="กรอกชื่อบัญชี" 
          />
        </a-form-item>
        <a-form-item label="รหัสผ่าน" name="emp_password" :rules="isEditing ? [] : rules.emp_password">
          <a-input-password 
            v-model:value="formData.emp_password" 
            :placeholder="isEditing ? 'เว้นว่างไว้หากไม่ต้องการเปลี่ยนรหัสผ่าน' : 'กรอกรหัสผ่าน'"
            :maxlength="32"
            @keydown="blockPassword" 
          />
        </a-form-item>
        <a-form-item label="เบอร์โทรศัพท์" name="emp_phone">
          <a-input 
            v-model:value="formData.emp_phone" 
            placeholder="กรอกเบอร์โทรศัพท์" 
            :maxlength="12"
            @keydown="blockNonNumeric"
            @input="formatPhoneNumber" 
          />
        </a-form-item>
        <a-form-item label="ฝ่าย" name="emp_department">
          <a-input 
            v-model:value="formData.emp_department"
            :maxlength="32" 
            placeholder="กรอกฝ่าย" 
          />
        </a-form-item>
        <a-form-item label="แผนก" name="emp_section">
          <a-input 
            v-model:value="formData.emp_section" 
            :maxlength="32"
            placeholder="กรอกแผนก" 
          />
        </a-form-item>
        <a-form-item label="ตำแหน่ง" name="emp_position">
          <a-input 
            v-model:value="formData.emp_position" 
            :maxlength="32"
            placeholder="กรอกตำแหน่ง" 
          />
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

const auth = localStorage.getItem("auth");

const rules = {
  emp_firstname: [
    { required: true, message: "กรุณากรอก ชื่อ" },
    { min: 1, max: 32 }
  ],
  emp_lastname: [
    { required: true, message: "กรุณากรอก นามสกุล" },
    { min: 1, max: 32 }
  ],
  emp_email: [
  { required: true, message: "กรุณากรอก อีเมล" },
  { type: "email", message: "กรุณากรอกอีเมลให้ถูกต้อง เช่น name@gmail.com" }
  ],
  emp_username: [
    { required: true, message: "กรุณากรอก ชื่อบัญชี" },
    { min: 1, max: 32 }
  ],
  emp_password: [
  { required: !isEditing.value, message: "กรุณากรอก รหัสผ่าน" },
  { 
    pattern: /^(?=.*[A-Z])(?=.*\d)[A-Za-z\d!@#$%^&*()_\-={}[\]':"\\|,.<>/?]{6,32}$/, 
    message: "รหัสผ่านต้องมี 6–32 ตัวอักษร โดยต้องมีตัวพิมพ์ใหญ่และตัวเลข และใช้อักขระพิเศษได้เฉพาะ !@#$%^&*()-_=+?.," 
  }
  ],
  emp_phone: [
    { required: true, message: "กรุณากรอกเบอร์โทรศัพท์" },
    { pattern: /^\d{3}-\d{3}-\d{4}$/, message: "เบอร์โทรต้องเป็นตัวเลข 10 หลัก" }
  ],
  emp_department: [
    { required: true, message: "กรุณากรอก ชื่อฝ่าย" },
    { min: 1, max: 32 }
  ],
  emp_section: [
    { required: true, message: "กรุณากรอก ชื่อแผนก" },
    { min: 1, max: 32 }
  ],
  emp_position: [
    { required: true, message: "กรุณากรอก ชื่อตำแหน่ง" },
    { min: 1, max: 32 }
  ]
};

const formData = reactive({
  emp_id: "",
  emp_firstname: "",
  emp_lastname: "",
  emp_email: "",
  emp_username: "",
  emp_password: "",
  emp_phone: "",
  emp_department: "",
  emp_section: "",
  emp_position: ""
})

// columns
const columns = [
  { title: "ชื่อ", dataIndex: "emp_firstname", key: "emp_firstname" },
  { title: "นามสกุล", dataIndex: "emp_lastname", key: "emp_lastname" },
  { title: "อีเมล", dataIndex: "emp_email", key: "emp_email" },
  { title: "ชื่อบัญชี", dataIndex: "emp_username", key: "emp_username" },
  { title: "เบอร์โทรศัพท์", dataIndex: "emp_phone", key: "emp_phone" },
  { title: "ฝ่าย", dataIndex: "emp_department", key: "emp_department" },
  { title: "แผนก", dataIndex: "emp_section", key: "emp_section" },
  { title: "ตำแหน่ง", dataIndex: "emp_position", key: "emp_position" },
  { title: "การจัดการ", key: "action" }
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
  let digits = formData.emp_phone.replace(/\D/g, "");

  // จำกัดความยาวไม่เกิน 10 หลัก
  digits = digits.slice(0, 10);

  // จัดรูปแบบ 3-3-4
  if (digits.length > 6) {
    formData.emp_phone =
      digits.slice(0, 3) + "-" + digits.slice(3, 6) + "-" + digits.slice(6);
  } else if (digits.length > 3) {
    formData.emp_phone =
      digits.slice(0, 3) + "-" + digits.slice(3);
  } else {
    formData.emp_phone = digits;
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

// โหลดข้อมูลพนักงาน
const fetchemps = async () => {
  try {
    isLoading.value = true;
    const res = await axios.get("/employee/show_employee", {
      headers: { Authorization: `Basic ${auth}` },
    });

    if (res.data && res.data.data && Array.isArray(res.data.data)) {
      data.value = res.data.data;
    } else {
      data.value = [];
      console.warn("Backend returned success but data is empty or not an array");
    }
  } catch (error) {
    console.error("Fetch Error:", error);
    message.error("โหลดข้อมูลพนักงานไม่สำเร็จ");
    data.value = [];
  } finally {
    isLoading.value = false;
  }
};

// modal control
const addemp = async () => {
  formKey.value++
  Object.assign(formData, {
    emp_id: "",
    emp_firstname: "",
    emp_lastname: "",
    emp_email: "",
    emp_username: "",
    emp_password: "",
    emp_phone: "",
    emp_department: "", 
    emp_section: "",    
    emp_position: ""
  })
  isEditing.value = false
  isModalVisible.value = true
}

const editemp = async (record) => {
  formKey.value++
  
  const editData = { ...record };

  if (editData.emp_phone) {
    let digits = editData.emp_phone.replace(/\D/g, "");
    if (digits.length === 10) {
      editData.emp_phone = `${digits.slice(0, 3)}-${digits.slice(3, 6)}-${digits.slice(6)}`;
    }
  }

  Object.assign(formData, editData);
  formData.emp_password = "";
  isEditing.value = true;
  isModalVisible.value = true;
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
    const payload = { 
      ...formData, 
      emp_phone: formData.emp_phone.replace(/\D/g, "")
    };
    const { emp_id, ...dataToSend } = payload;
    const res = await axios.put("/employee/add_employee", dataToSend)
    message.success(res.data.message || "บันทึกสำเร็จ")
    await fetchemps()
    closeModal()
  } catch (error) {
    message.error(error.response?.data?.message || "บันทึกไม่สำเร็จ")
  }
}

// save edit
const saveEdit = async () => {
  try {
    await forRef.value.validate();
    const payload = { 
      ...formData, 
      emp_phone: formData.emp_phone.replace(/\D/g, "")
    };
    const res = await axios.patch("/employee/edit_employee", payload)
    message.success(res.data.message || "แก้ไขสำเร็จ")
    await fetchemps()
    closeModal()
  } catch (error) {
    message.error(error.response?.data?.message || "อัปเดตไม่สำเร็จ")
  }
}

// delete
const deleteRow = async (emp_id) => {
      try {
        const res = await axios.patch("/employee/delete_employee", { emp_id })
        message.success(res.data.message || "ลบสำเร็จ")
        await fetchemps()
      } catch (error) {
        message.error(error.response?.data?.message || "ลบไม่สำเร็จ")
      }
    }

// โหลดข้อมูลตอนเข้า
onMounted(async () => {
  isLoading.value = true           
  await fetchemps();          
  isLoading.value = false;         
});

</script>

<style scoped>
.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.search-input {
  width: 300px;
  height: 32px;
}

:deep(.search-input .ant-input) {
  height: 32px;
}

:deep(.search-input .ant-btn) {
  height: 32px;
  line-height: 32px;
}

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
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.styled-table {
  background-color: #fff;
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid #f0f4f2;
}

:deep(.ant-table-thead > tr > th) {
  background: #f8fbf9 !important;
  color: #64748b !important;
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  border-bottom: 1.5px solid #e8f5f1 !important;
}

:deep(.ant-table-tbody > tr > td) {
  border-bottom: 1px solid #f4f7f6 !important;
  font-size: 13.5px;
}

:deep(.ant-table-tbody > tr:hover > td) {
  background: rgba(0,200,150,0.04) !important;
}

:deep(.ant-table-container) { border-radius: 14px !important; overflow: hidden !important; }

:deep(.ant-pagination-item-active) {
  background: #00C896 !important;
  border-color: #00C896 !important;
}
:deep(.ant-pagination-item-active a) { color: white !important; }

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
  .toolbar { flex-wrap: wrap; gap: 10px; }
  .btn-Add { font-size: 14px; }
}

</style>