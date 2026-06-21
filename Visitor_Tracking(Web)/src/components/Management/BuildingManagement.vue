<template>
  <a-spin :spinning="isLoading" tip="กำลังโหลดข้อมูล...">
  <div class="container-fluid my-4">
    <!-- Toolbar -->
    <div class="toolbar">
      <!-- Search -->
      <a-input
        class="search-input"
        v-model:value="searchValue"
        placeholder="ค้นหา อาคาร..."
        enter-button="ค้นหา"
        size="large"
      />

      <!-- กล่อง switch, เพิ่มอาคาร -->
      <div class="toolbar-right ms-auto">
        <!-- ปุ่มสลับ ตาราง/แผนที่ -->
        <a-segmented
          v-model:value="viewMode"
          :options="segmentedOptions"
          class="viewmode-segmented"
          style="margin-right: 12px;"
        />
        <!-- Add button -->
        <a-button type="primary" class="btn-Add" @click="showModal">
          <i class="bi bi-plus-circle me-1"></i> เพิ่มอาคาร
        </a-button>
      </div>
    </div>

    <!-- ตาราง -->
    <div class="card-table p-3 rounded shadow-sm">
      <a-table
        bordered
        :data-source="filteredData"
        :columns="columns"
        rowKey="b_id"
        :pagination="pagination"
        :scroll="{ x: 400 }"
        @change="handleTableChange"
        class="styled-table"
      >
        <template #bodyCell="{ column, text, record }">
          <template v-if="column.key !== 'action'">
            {{ text }}
          </template>
          <template v-else>
            <!-- ปุ่มแก้ไข -->
            <edit-outlined class="editable-cell-icon" @click="openEditModal(record)" />
            <a-divider type="vertical" />
            <!-- ปุ่มลบ -->
            <a-popconfirm title="ยืนยันการลบ อาคาร นี้หรือไม่?" ok-text="ยืนยัน" cancel-text="ยกเลิก" @confirm="deleteBuilding(record.b_id)">
              <delete-outlined class="editable-cell-icon-close" />
            </a-popconfirm>
          </template>
        </template>
      </a-table>
    </div>

    <!-- Modal Add -->
    <a-modal
      v-model:open="showAddModal"
      title="เพิ่มอาคาร"
      :ok-text="'บันทึก'"
      :cancel-text="'ยกเลิก'"
      @ok="saveAdd"
      class="scrollable-modal"
      :bodyStyle="{ padding: '16px 24px', overflowY: 'auto' }"
      :maskClosable="false"
      :style="{ top: '70px'}"
    >
      <a-form 
        layout="vertical"
        :model="addFormData"
        :rules="rules"
        ref="forRef"
        :requiredMark="false"
      >
        <a-form-item label="ชื่ออาคาร" name="b_name">
          <a-input 
            v-model:value="addFormData.b_name"
            :maxlength="60" 
          />
        </a-form-item>
        <a-form-item label="ที่อยู่" name="b_address">
          <a-input v-model:value="addFormData.b_address" />
        </a-form-item>
        <a-form-item label="ละติจูด" name="b_lat">
          <a-input-number 
            v-model:value="addFormData.b_lat"
            :controls="false"
            :precision="14"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="ลองจิจูด" name="b_long">
          <a-input-number 
            v-model:value="addFormData.b_long"
            :controls="false"
            :precision="14"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="เลือกตำแหน่งบนแผนที่">
          <div style="position: relative; height: 100px;">

            <div v-if="isLocatingInModal" style="
              position: absolute;
              top: 0; left: 0;
              width: 100%; height: 300px;
              background: rgba(255,255,255,0.85);
              z-index: 99999;
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              border-radius: 4px;
              gap: 10px;
            ">
              <a-spin size="large" />
              <span style="color: #555; font-size: 14px;">กำลังโหลดตำแหน่งปัจจุบัน...</span>
            </div>

            <l-map
              style="height: 300px"
              :zoom="17"
              :center="[addFormData.b_lat, addFormData.b_long]"
              :editable="true"
              @click="onMapClickAdd"
            >
              <l-tile-layer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
              <l-marker
                v-if="addFormData.b_lat && addFormData.b_long"
                :lat-lng="[addFormData.b_lat, addFormData.b_long]"
              />
              <l-circle
                v-if="addFormData.b_lat && addFormData.b_long"
                :lat-lng="[addFormData.b_lat, addFormData.b_long]"
                :radius="addFormData.b_radius"
                color="blue"
              />
            </l-map>
            <div class="map-slider">
              <a-slider
                v-model:value="addFormData.b_radius"
                :min="50"
                :max="1000"
                :step="1"
                style="width: 250px;"
              />
            </div>
            <a-form-item label="เขตรอบอาคาร (เมตร)" name="b_radius">
              <a-input-number 
                v-model:value="addFormData.b_radius" 
                :min="50" 
                :max="1000" 
              />
            </a-form-item>
          </div>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- Modal Edit -->
    <a-modal
      v-model:open="showEditModal"
      title="แก้ไขข้อมูลอาคาร"
      :ok-text="'บันทึก'"
      :cancel-text="'ยกเลิก'"
      @ok="saveEdit"
      class="scrollable-modal"
      :bodyStyle="{padding: '16px 24px', overflowY: 'auto' }"
      :maskClosable="false"
      :style="{ top: '70px'}"
    >
      <a-form 
        layout="vertical"
        :model="editFormData"
        :rules="rules"
        ref="editFormRef"
        :requiredMark="false"
      >
        <a-form-item label="ชื่ออาคาร" name="b_name">
          <a-input v-model:value="editFormData.b_name" :maxlength="60" />
        </a-form-item>
        <a-form-item label="ที่อยู่" name="b_address">
          <a-input v-model:value="editFormData.b_address" />
        </a-form-item>
        <a-form-item label="ละติจูด" name="b_lat">
          <a-input-number 
            v-model:value="editFormData.b_lat"
            :controls="false"
            :precision="14"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="ลองจิจูด" name="b_long">
          <a-input-number 
            v-model:value="editFormData.b_long"
            :controls="false"
            :precision="14"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="เลือกตำแหน่งบนแผนที่">
          <div style="position: relative; height: 100px;">
            <l-map
              style="height: 300px"
              :zoom="17"
              :center="[editFormData.b_lat, editFormData.b_long]"
              :editable="true"
              @click="onMapClickEdit"
            >
              <l-tile-layer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />

              <l-marker
                v-if="editFormData.b_lat && editFormData.b_long"
                :lat-lng="[editFormData.b_lat, editFormData.b_long]"
              />
              <l-circle
                v-if="editFormData.b_lat && editFormData.b_long"
                :lat-lng="[editFormData.b_lat, editFormData.b_long]"
                :radius="editFormData.b_radius"
                color="blue"
              />
            </l-map>
            <div class="map-slider">
              <a-slider
                v-model:value="editFormData.b_radius"
                :min="50"
                :max="1000"
                :step="1"
                style="width: 250px;"
              />
            </div>
            <a-form-item label="เขตรอบอาคาร (เมตร)" name="b_radius">
              <a-input-number 
                v-model:value="editFormData.b_radius" 
                :min="50" 
                :max="1000" 
              />
            </a-form-item>
          </div>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
  </a-spin>
</template>

<script setup>
import { ref, computed, onMounted, watch, h } from "vue";
import L from "leaflet";
import axios from '@/axios';
import { message } from "ant-design-vue";
import { useRouter, useRoute } from "vue-router";
import { EnvironmentOutlined, CalendarOutlined, EditOutlined, DeleteOutlined  } from "@ant-design/icons-vue";
import { LMap, LTileLayer, LMarker, LCircle } from "@vue-leaflet/vue-leaflet";
import "leaflet/dist/leaflet.css";
import iconUrl from 'leaflet/dist/images/marker-icon.png';
import iconRetinaUrl from 'leaflet/dist/images/marker-icon-2x.png';
import shadowUrl from 'leaflet/dist/images/marker-shadow.png';


// Fix Leaflet marker icons
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl,
  iconRetinaUrl,
  shadowUrl,
});

const router = useRouter();
const route = useRoute();

const searchValue = ref("");
const dataSource = ref([]);
const viewMode = ref("table");
const isLoading = ref(true);
const isLocatingInModal = ref(false);

const showAddModal = ref(false);
const showEditModal = ref(false);
const forRef = ref(null);
const editFormRef = ref(null);

const rules = { 
  b_name: [{ required: true, message: "กรุณากรอกชื่ออาคาร" }, { max: 60, message: "ชื่ออาคารต้องไม่เกิน 60 ตัวอักษร" }],
  b_address: [{ required: true, message: "กรุณากรอกที่อยู่" }],
  b_lat: [{ required: true, message: "กรุณาระบุละติจูด" }],
  b_long: [{ required: true, message: "กรุณาระบุลองจิจูด" }],
  b_radius: [{ required: true, message: "กรุณาระบุรัศมี" }]
};

const columns = [
  { title: "ชื่ออาคาร", dataIndex: "b_name", key: "b_name" },
  { title: "ที่อยู่", dataIndex: "b_address", key: "b_address" },
  { title: "ละติจูด", dataIndex: "b_lat", key: "b_lat" },
  { title: "ลองจิจูด", dataIndex: "b_long", key: "b_long" },
  { title: "รัศมี (เมตร)", dataIndex: "b_radius", key: "b_radius" },
  { title: "การจัดการ", key: "action" },
];

// Add form
const addFormData = ref({
  b_name: "",
  b_address: "",
  b_lat: 13.67860849872953,
  b_long: 100.60310268389006,
  b_radius: 50,
});

// Edit form
const editFormData = ref({
  b_id: null,
  b_name: "",
  b_address: "",
  b_lat: 13.6786,
  b_long: 100.6031,
  b_radius: 50,
});

const fetchBuilding = async () => {
  try {
    isLoading.value = true 
    const res = await axios.get("/building/show_building");
    dataSource.value = Array.isArray(res.data) ? res.data : res.data.data || [];
  } catch (error) {
    console.error("โหลดข้อมูลไม่สำเร็จ:", error);
  } finally {
    isLoading.value = false;
  }
};

const showModal = () => {
  addFormData.value = { 
    b_name: "", 
    b_address: "", 
    b_lat: 13.6786, 
    b_long: 100.6031, 
    b_radius: 50 
  };

  showAddModal.value = true;
  isLocatingInModal.value = true;

  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const lat = position.coords.latitude;
        const lng = position.coords.longitude;

        addFormData.value.b_lat = lat;
        addFormData.value.b_long = lng;

        try {
          const res = await axios.get("https://nominatim.openstreetmap.org/reverse", {
            params: { lat, lon: lng, format: "json", addressdetails: 1 }
          });
          addFormData.value.b_address = res.data.display_name;
        } catch (err) {
          console.error("reverse geocode error:", err);
          addFormData.value.b_address = "";
        }

        isLocatingInModal.value = false;
      },
      (error) => {
        console.error("Geolocation error:", error);
        message.warning("ไม่สามารถระบุตำแหน่งอัตโนมัติได้ จะใช้พิกัดเริ่มต้นแทน");
        isLocatingInModal.value = false;
      },
      { enableHighAccuracy: true, timeout: 5000 }
    );
  } else {
    message.error("เบราว์เซอร์ของคุณไม่รองรับการระบุตำแหน่ง");
    isLocatingInModal.value = false;
  }
};

const saveAdd = async () => {
  try {
    await forRef.value.validate();
    await axios.put("/building/add_building", addFormData.value);
    message.success("เพิ่มอาคารสำเร็จ");
    showAddModal.value = false;
    fetchBuilding();
  } catch {
    message.error("เพิ่มอาคารไม่สำเร็จ");
  }
};

const saveEdit = async () => {
  try {
    await editFormRef.value.validate();
    await axios.patch("/building/edit_building", editFormData.value);
    message.success("แก้ไขอาคารสำเร็จ");
    showEditModal.value = false;
    fetchBuilding();
  } catch {
    message.error("แก้ไขไม่สำเร็จ กรุณาตรวจสอบข้อมูล");
  }
};

const deleteBuilding = async (b_id) => {
  try {
    await axios.patch("/building/delete_building", { b_id });
    message.success("ลบอาคารสำเร็จ");
    fetchBuilding();
  } catch {
    message.error("ลบไม่สำเร็จ");
  }
};

// filter Search
const filteredData = computed(() => {
  if (!searchValue.value) return dataSource.value;
  const searchParts = searchValue.value.toLowerCase().split(/\s+/); 

  return dataSource.value.filter((item) => {
    const itemText = Object.values(item).join(" ").toLowerCase();
    return searchParts.every(part => itemText.includes(part));
  });
});

const pagination = ref({
  current: 1,
  pageSize: 10,
  showSizeChanger: true,
  pageSizeOptions: ["5", "10", "20", "50"],
});

const handleTableChange = (pag) => {
  pagination.value = { ...pagination.value, ...pag };
};

const segmentedOptions = [
  {
    label: h("span", [h(CalendarOutlined, { style: "margin-right: 4px;" }), "ตาราง"]),
    value: "table",
  },
  {
    label: h("span", [h(EnvironmentOutlined, { style: "margin-right: 4px;" }), "แผนที่"]),
    value: "map",
  },
];

watch(viewMode, (val) => {
  if (val === "table") {
    router.push("/admin/building");
  } else if (val === "map") {
    router.push("/admin/mapmanagement");
  }
});

onMounted(() => {
  fetchBuilding();
  if (route.path.includes("/admin/building")) {
    viewMode.value = "table";
  } else if (route.path.includes("/admin/mapmanagement")) {
    viewMode.value = "map";
  }
});

const openEditModal = (record) => {
  editFormData.value = { ...record };
  showEditModal.value = true;
};

const fetchAddress = async (lat, lng) => {
  try {
    const res = await axios.get(
      `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json`
    );
    return res.data.display_name || "";
  } catch (e) {
    console.error("Reverse geocoding error:", e);
    return "";
  }
};

const onMapClickAdd = async (e) => {
  addFormData.value.b_lat = e.latlng.lat;
  addFormData.value.b_long = e.latlng.lng;
  addFormData.value.b_address = await fetchAddress(e.latlng.lat, e.latlng.lng);
};

const onMapClickEdit = async (e) => {
  editFormData.value.b_lat = e.latlng.lat;
  editFormData.value.b_long = e.latlng.lng;
  editFormData.value.b_address = await fetchAddress(e.latlng.lat, e.latlng.lng);
};
</script>

<style scoped>
.toolbar {
  display: flex;
  justify-content: space-between;
  margin-bottom: 16px;
  align-items: center;
}

.toolbar-right {
  display: flex;
  align-items: center;
}

.toolbar-floating .ant-segmented {
  height: 40px;
  line-height: 40px;
  font-size: 14px;
  background-color: #f5f5f5;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  display: flex;
  align-items: center;
}

.toolbar-floating .ant-segmented-item {
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 16px;
}

:deep(.toolbar-floating .ant-segmented-item-selected) {
  background-color: #1890ff !important;
  color: white !important;
  font-weight: 500;
}

:deep(.toolbar-floating .ant-segmented-item-selected svg) {
  color: white !important;
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

.card-table {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.styled-table {
  background-color: #fff;
  border-radius: 8px;
  overflow: hidden;
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

:deep(.ant-segmented-item-selected) {
  background-color: #093b69 !important;
  color: white !important;
}
:deep(.ant-segmented-item-selected svg) {
  color: white !important;
}
.map-slider {
  position: absolute;
  top: 330px;
  right: 1px;
  height: 30px;
  background: white;
  padding: 8px;
  border-radius: 8px;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.2);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
}

:deep(.scrollable-modal .ant-modal-content) {
  max-height: 80vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

:deep(.scrollable-modal .ant-modal-body) {
  flex: 1;
  overflow-y: auto;
  padding-right: 12px;
  max-height: calc(80vh - 100px);
  box-sizing: border-box;
  scrollbar-width: thin;
  scrollbar-color: #c1c1c1 #f5f5f5;
}

:deep(.scrollable-modal .ant-modal-body::-webkit-scrollbar) {
  width: 8px;
}

:deep(.scrollable-modal .ant-modal-body::-webkit-scrollbar-thumb) {
  background-color: #c1c1c1;
  border-radius: 8px;
}

:deep(.scrollable-modal .ant-modal-body) {
  scroll-behavior: smooth;
}

:global(body.ant-scrolling-effect) {
  overflow: hidden !important;
  height: 100vh !important;
}

:global(.ant-modal-wrap) {
  overflow: hidden !important;
}

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