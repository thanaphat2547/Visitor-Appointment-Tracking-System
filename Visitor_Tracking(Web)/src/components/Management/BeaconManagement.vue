<template>
  <a-spin :spinning="isLoading" tip="กำลังโหลดข้อมูล...">
  <div class="container-fluid my-4">
    <!-- Toolbar -->
    <div class="toolbar">
      <!-- Search -->
      <a-input
        class="search-input"
        v-model:value="searchValue"
        placeholder="ค้นหา อุปกรณ์บีคอน..."
        enter-button="ค้นหา"
        size="large"
      />

      <!-- Add button -->
      <a-button type="primary" class="btn-Add" @click="addBeacon">
        <i class="bi bi-plus-circle me-1"></i> เพิ่มอุปกรณ์บีคอน
      </a-button>
    </div>

    <!-- ตาราง -->
    <div class="card-table p-3 rounded shadow-sm">
      <a-table
        bordered
        :data-source="filteredData"
        :columns="columns"
        rowKey="bc_id"
        :pagination="pagination"
        @change="handleTableChange"
        class="styled-table"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key !== 'action'">
            {{ record[column.dataIndex] }}
          </template>
          <template v-else>
            <!-- ปุ่มแก้ไข -->
            <edit-outlined class="editable-cell-icon" @click="editBeacon(record)" />
            <a-divider type="vertical" />
            <!-- ปุ่มลบ -->
            <a-popconfirm title="ยืนยันการลบ อุปกรณ์บีคอน นี้หรือไม่?" ok-text="ยืนยัน" cancel-text="ยกเลิก" @confirm="deleteRow(record.bc_id)">
              <delete-outlined class="editable-cell-icon-close" />
            </a-popconfirm>
          </template>
        </template>
      </a-table>
    </div>

    <!-- Modal Add/Edit -->
    <a-modal
      :title="isEditing ? 'แก้ข้อมูลอุปกรณ์บีคอน' : 'เพิ่มอุปกรณ์บีคอน'"
      v-model:open="isModalVisible"
      @ok="isEditing ? saveEdit() : saveAdd()"
      @cancel="closeModal"
      ok-text="บันทึก"
      cancel-text="ยกเลิก"
    >
      <a-form 
        :key="formKey"
        layout="vertical"
        :model="formData"
        :rules="rules"
        ref="forRef"
        :requiredMark="false"
      >
        <a-form-item label="ชื่ออุปกรณ์บีคอน" name="bc_name">
          <a-input 
            v-model:value="formData.bc_name" 
            placeholder="กรอก ชื่ออุปกรณ์บีคอน"
            @keydown="blockSpecialCharacters" 
            @paste="cleanNamePaste"
          />
        </a-form-item>

        <a-form-item label="UUID" name="bc_uuid">
          <a-input
            :value="formData.bc_uuid"
            placeholder="กรอก UUID(อุปกรณ์บีคอน)"
            @input="onUUIDInput"
            @keydown="blockNonEnglishUUID"
            @paste="cleanUUIDPaste"
          />
        </a-form-item>

        <a-form-item label="อาคาร/สถานที่ติดตั้ง" name="b_id">
            <a-select
              v-model:value="formData.b_id"
              placeholder="เลือกอาคารที่ติดตั้ง"
              show-search
              option-filter-prop="label"
            >
              <a-select-option v-for="b in buildings" :key="b.b_id" :value="b.b_id" :label="b.b_name">
                {{ b.b_name }}
              </a-select-option>
            </a-select>
        </a-form-item>

      </a-form>
    </a-modal>
  </div>
  </a-spin>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from "vue";
import axios from "@/axios";
import { message } from "ant-design-vue";
import { EditOutlined, DeleteOutlined } from "@ant-design/icons-vue";

// state
const data = ref([]);
const buildings = ref([]);
const searchValue = ref("");
const isModalVisible = ref(false);
const isEditing = ref(false);
const forRef = ref(null);
const formKey = ref(0)
const isLoading = ref(true)

const rules = {
  bc_name: [{ required: true, message: "กรุณากรอกชื่ออุปกรณ์บีคอน" }],
  bc_uuid: [{ required: true, message: "กรุณากรอก UUID" }],
  b_id: [{ required: true, message: "กรุณาเลือกอาคาร" }],
};

const formData = reactive({
  bc_id: "",
  b_id: null,
  bc_name: "",
  bc_uuid: ""
});

// columns
const columns = [
  { title: "ชื่ออุปกรณ์บีคอน", dataIndex: "bc_name", key: "bc_name" },
  { title: "UUID (อุปกรณ์บีคอน)", dataIndex: "bc_uuid", key: "bc_uuid" },
  { title: "อาคาร", dataIndex: "b_name", key: "b_name" },
  { title: "การจัดการ", key: "action" }
];

// pagination
const pagination = ref({
  current: 1,
  pageSize: 5,
  showSizeChanger: true,
  pageSizeOptions: ["5", "10", "20"],
});

// กรองชื่อบีคอน ตอนพิมให้กรอกได้แค่ ภาษาอังกฤษกับไทย
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

  if (!controlKeys.includes(e.key) && formData.bc_name.length >= 32) {
    e.preventDefault()
  }
}

// กรองชื่อบีคอน ตอนคัดลอกมาวางให้กรอกได้แค่ ภาษาอังกฤษกับไทย
const cleanNamePaste = (e) => {
  const pasted = e.clipboardData.getData("text")
  const clean = pasted.replace(/[^ก-ฮะ-์a-zA-Z\s]/g, "") 
  e.preventDefault()

  const remaining = 32 - formData.bc_name.length
  formData.bc_name += clean.slice(0, remaining)
}

// กรองข้อมูล UUID
const onUUIDInput = (e) => {
  const input = e.target.value || ""

  // กรองเฉพาะภาษาอังกฤษและตัวเลขเท่านั้น
  const raw = input.replace(/[^a-zA-Z0-9]/g, "").slice(0, 32)

  // จัดรูปแบบ UUID เป็น 8-4-4-4-12
  const sections = [8, 4, 4, 4, 12]
  let formatted = ""
  let index = 0

  for (let i = 0; i < sections.length; i++) {
    if (raw.length > index) {
      formatted += raw.slice(index, index + sections[i])
      index += sections[i]
      if (i < sections.length - 1 && raw.length > index) {
        formatted += "-"
      }
    }
  }

  formData.bc_uuid = formatted
}

const blockNonEnglishUUID = (e) => {
  const allowed = /[a-zA-Z0-9]/
  const controlKeys = [
    "Backspace", "Delete", "ArrowLeft", "ArrowRight",
    "Tab", "Enter", "Escape", "Home", "End"
  ]

  if (!allowed.test(e.key) && !controlKeys.includes(e.key)) {
    e.preventDefault()
  }
}

const cleanUUIDPaste = (e) => {
  const pasted = e.clipboardData.getData("text") || ""

  // กรองเฉพาะภาษาอังกฤษและตัวเลขเท่านั้น
  const raw = pasted.replace(/[^a-zA-Z0-9]/g, "").slice(0, 32)

  // จัดรูปแบบ UUID เป็น 8-4-4-4-12
  const sections = [8, 4, 4, 4, 12]
  let formatted = ""
  let index = 0

  for (let i = 0; i < sections.length; i++) {
    if (raw.length > index) {
      formatted += raw.slice(index, index + sections[i])
      index += sections[i]
      if (i < sections.length - 1 && raw.length > index) {
        formatted += "-"
      }
    }
  }

  e.preventDefault()
  formData.bc_uuid = formatted
}

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
  pagination.value = { ...pagination.value, ...pag };
};

// โหลดข้อมูลอาคาร
const fetchBuildings = async () => {
  try {
    const res = await axios.get("/building/show_building");
    buildings.value = res.data.data || [];
  } catch (error) {
    console.error("โหลดข้อมูลอาคารไม่สำเร็จ", error);
  }
};

// โหลดข้อมูลบีคอน
const fetchBeacons = async () => {
  try {
    const res = await axios.get("/beacon/show_beacon");
    if (Array.isArray(res.data)) {
      data.value = res.data;
    } else if (Array.isArray(res.data.data)) {
      data.value = res.data.data;
    } else {
      data.value = [];
    }
  } catch (error) {
    if (error.response?.status === 403) {
      message.error("คุณไม่มีสิทธิ์เข้าถึงข้อมูล");
    } else if (error.response?.status === 401) {
      message.error("กรุณาเข้าสู่ระบบใหม่");
    } else {
      message.error("โหลดข้อมูลไม่สำเร็จ");
    }
    data.value = [];
  }
};

// modal control
const addBeacon = () => {
  formKey.value++
  Object.assign(formData, {
    bc_id: "",
    b_id: null,
    bc_name: "",
    bc_uuid: ""
  })
  isEditing.value = false
  isModalVisible.value = true
}

const editBeacon = (record) => {
  formKey.value++ 
  Object.assign(formData, {
    bc_id: record.bc_id,
    b_id: record.b_id,
    bc_name: record.bc_name,
    bc_uuid: record.bc_uuid
  })
  isEditing.value = true
  isModalVisible.value = true
}

const closeModal = () => {
  isModalVisible.value = false
}

// save add
const saveAdd = async () => {
  try {
    await forRef.value.validate();
    const res = await axios.put("/beacon/add_beacon", formData);
    message.success(res.data.message || "บันทึกสำเร็จ");
    await fetchBeacons();
    closeModal();
  } catch (error) {
    message.error(error.response?.data?.message || "ไม่สามารถบันทึกได้");
  }
};

const saveEdit = async () => {
  try {
    await forRef.value.validate();
    const res = await axios.patch("/beacon/edit_beacon", formData);
    message.success(res.data.message || "แก้ไขสำเร็จ");
    await fetchBeacons();
    closeModal();
  } catch (error) {
    message.error(error.response?.data?.message || "แก้ไขไม่สำเร็จ");
  }
};

const deleteRow = async (bc_id) => {
  try {
    const res = await axios.patch("/beacon/delete_beacon", { bc_id });
    message.success(res.data.message || "ลบสำเร็จ");
    await fetchBeacons();
  } catch (error) {
    message.error(error.response?.data?.message || "ลบไม่สำเร็จ");
  }
}

// โหลดข้อมูลเมื่อเข้า
onMounted(async () => {
  isLoading.value = true           
  await Promise.all([fetchBeacons(), fetchBuildings()]);          
  isLoading.value = false;         
});

</script>

<style scoped>
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
  border-radius: 14px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.05);
  border: 1px solid #f0f4f2;
  overflow: hidden;
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