<template>
  <a-spin :spinning="isLoading" tip="กำลังโหลดข้อมูล...">
  <div class="map-page-wrapper">
    <div class="map-page">

      <!-- Sidebar -->
      <div class="sidebar" :class="{ collapsed: collapsed }">
        
        <!-- Sidebar Header -->
        <div class="sidebar-header">
          <a-input
            class="search-input"
            v-model:value="searchValue"
            placeholder="ค้นหา อาคาร..."
            enter-button="ค้นหา"
            size="large"
          />
        </div>

        <!-- Building List -->
        <div class="building-list" v-if="!collapsed">
          <div
            v-for="b in filteredBuildings"
            :key="b.b_id"
            class="building-item"
            @click="focusBuilding(b)"
          >
            <div class="building-info">
              <div class="info-row">
                <div class="name">อาคาร: {{ b.b_name }}</div>
              </div>
              <a-button
                type="text"
                class="beacon-btn"
                @click.stop="focusBuilding(b)"
              >
                <DoubleRightOutlined style="font-size: 18px; color:#1890ff;" />
              </a-button>
            </div>
          </div>
        </div>

        <!-- ปุ่ม toggle -->
        <a-button 
          type="text" 
          @click="toggleSidebar" 
          class="toggle-btn"
        >
          <DoubleRightOutlined v-if="collapsed" />
          <DoubleLeftOutlined v-else />
        </a-button>
      </div>

      <!-- แผนที่ -->
      <div class="map-container" :class="{ 'collapsed-map': collapsed }">

        <!-- Toolbar ลอยบนแผนที่ -->
        <div class="toolbar-floating">
          <div class="toolbar-right">
            <a-segmented
              v-model:value="viewMode"
              :options="segmentedOptions"
              style="margin-right: 12px;"
            />
            <a-button type="primary" class="btn-Add" @click="showModal">
              <i class="bi bi-plus-circle me-1"></i> เพิ่มอาคาร
            </a-button>
          </div>
        </div>

        <l-map
          v-if="mapCenter"
          ref="mapRef"
          style="height: 100%; width: 100%"
          :center="mapCenter"
          :zoom="17"
          :editable="true"
        >
          <l-tile-layer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          <l-control-zoom position="bottomright" />

          <l-marker
            v-for="b in buildings"
            :key="b.b_id"
            :lat-lng="[b.b_lat, b.b_long]"
            @click="openEdit(b)"
          >
            <l-tooltip 
              class="building-tooltip" 
              :options="{ permanent: true, direction: 'top', offset: [-15, 0] }"
            >
              อาคาร: {{ b.b_name }}
            </l-tooltip>
          </l-marker>

          <l-circle
            v-for="b in buildings"
            :key="'circle-' + b.b_id"
            :lat-lng="[b.b_lat, b.b_long]"
            :radius="b.b_radius"
            color="blue"
            :editable="true"
            @editable:vertex:dragend="onCircleEdit(b, $event)"
            @editable:dragend="onCircleMove(b, $event)"
          />
        </l-map>
      </div>
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
        <a-form-item label="ที่อยู่">
          <a-input v-model:value="addFormData.b_address" />
        </a-form-item>
        <a-form-item label="ละติจูด">
          <a-input-number 
            v-model:value="addFormData.b_lat"
            :controls="false"
            :precision="14"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="ลองจิจูด">
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
                :editable="true"
                @editable:vertex:dragend="onAddCircleEdit($event)"
                @editable:dragend="onAddCircleMove($event)"
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
            <a-form-item label="เขตรอบอาคาร (เมตร)">
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
      :bodyStyle="{ padding: '16px 24px', overflowY: 'auto' }"
      :maskClosable="false"
      :style="{ top: '70px'}"
    >
      <a-form layout="vertical">
        <a-form-item label="ชื่ออาคาร">
          <a-input v-model:value="editFormData.b_name" />
        </a-form-item>
        <a-form-item label="ที่อยู่">
          <a-input v-model:value="editFormData.b_address" />
        </a-form-item>
        <a-form-item label="ละติจูด">
          <a-input-number 
            v-model:value="editFormData.b_lat"
            :controls="false"
            :precision="14"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="ลองจิจูด">
          <a-input-number 
            v-model:value="editFormData.b_long"
            :controls="false"
            :precision="14"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="เลือกตำแหน่งบนแผนที่">
          <div style="position: relative; height: 68px;">
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
                :editable="true"
                @editable:vertex:dragend="onEditCircleEdit($event)"
                @editable:dragend="onEditCircleMove($event)"
              />
            </l-map>

            <div class="map-slider">
              <a-slider
                v-model:value="editFormData.b_radius"
                :min="1"
                :max="1000"
                :step="1"
                style="width: 250px;"
              />
            </div>
            <a-form-item label="เขตรอบอาคาร (เมตร)">
              <a-input-number 
                v-model:value="editFormData.b_radius" 
                :min="1" 
                :max="1000"
              />
            </a-form-item>
          </div>
        </a-form-item>
      </a-form>

      <template #footer>
        <div style="display: flex; justify-content: space-between; width: 100%;">
          <a-button type="primary" danger @click="deleteBuilding(editFormData.b_id)">
            ลบอาคาร
          </a-button>
          <div>
            <a-button style="margin-right: 8px;" @click="showEditModal = false">
              ยกเลิก
            </a-button>
            <a-button type="primary" @click="saveEdit">
              บันทึก
            </a-button>
          </div>
        </div>
      </template>
    </a-modal>

  </div>
  </a-spin>
</template>

<script setup>
import { ref, onMounted, computed, watch, h, nextTick } from "vue";
import axios from '@/axios';
import L from "leaflet";
import "leaflet-editable";
import { LMap, LTileLayer, LMarker, LCircle, LControlZoom, LTooltip } from "@vue-leaflet/vue-leaflet";
import "leaflet/dist/leaflet.css";
import iconUrl from 'leaflet/dist/images/marker-icon.png';
import iconRetinaUrl from 'leaflet/dist/images/marker-icon-2x.png';
import shadowUrl from 'leaflet/dist/images/marker-shadow.png';
import { message } from 'ant-design-vue';
import { useRouter, useRoute } from "vue-router";
import { EnvironmentOutlined, CalendarOutlined, DoubleLeftOutlined, DoubleRightOutlined } from '@ant-design/icons-vue';

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({ iconUrl, iconRetinaUrl, shadowUrl });

const router = useRouter();
const route = useRoute();
const mapRef = ref(null);
const buildings = ref([]);
const searchValue = ref("");
const forRef = ref(null);
const isLoading = ref(true);
const isLocatingInModal = ref(false);
const mapCenter = ref([13.6793, 100.6031]);

const rules = { 
  b_name: [
    { required: true, message: "กรุณากรอกชื่ออาคาร" }, 
    { max: 60, message: "ชื่ออาคารต้องไม่เกิน 60 ตัวอักษร" }
  ] 
};

const props = defineProps({ isSiderCollapsed: Boolean });
const collapsed = ref(props.isSiderCollapsed);
const emit = defineEmits(['update:isSiderCollapsed']);

const safeInvalidateSize = (map) => {
  try {
    if (map && map._loaded && map.getContainer() && map.getPane('mapPane')) {
      map.invalidateSize();
    }
  } catch (e) {
  }
};

const safeSetView = (map, coords, zoom) => {
  try {
    if (map && map._loaded && map.getContainer() && map.getPane('mapPane') && coords && Array.isArray(coords)) {
      map.setView(coords, zoom);
    }
  } catch (e) {
  }
};

watch(() => props.isSiderCollapsed, (val) => {
  collapsed.value = val; 

  nextTick(() => {
    setTimeout(() => {
      const map = mapRef.value?.leafletObject;
      if (map) {
        safeInvalidateSize(map);
      }
    }, 310);
  });
});

watch(() => collapsed.value, () => {
  const map = mapRef.value?.leafletObject;
  if (map) {
    nextTick(() => {
      safeInvalidateSize(map);
      updateMapCenter();
    });
  }
});

const toggleSidebar = () => {
  collapsed.value = !collapsed.value;
  emit('update:isSiderCollapsed', collapsed.value);
  const map = mapRef.value?.leafletObject;
  if (map) {
    setTimeout(() => {
      safeInvalidateSize(map);
      updateMapCenter();
    }, 310);
  }
};

const filteredBuildings = computed(() => {
  if (!searchValue.value) return buildings.value;
  return buildings.value.filter(b => 
    b.b_name.toLowerCase().includes(searchValue.value.toLowerCase()) ||
    b.b_address.toLowerCase().includes(searchValue.value.toLowerCase())
  );
});

const focusBuilding = (building) => {
  const map = mapRef.value?.leafletObject;
  if (map) {
    safeSetView(map, [building.b_lat, building.b_long], 18);
  }
};

const viewMode = ref(route.path.includes("/admin/mapmanagement") ? "map" : "table");

const fetchBuildings = async () => {
  try {
    const res = await axios.get("/building/show_building");
    const rawData = res.data.data || res.data;
    if (Array.isArray(rawData)) {
      buildings.value = rawData.map((b) => ({
        ...b,
        b_lat: Number(b.b_lat),
        b_long: Number(b.b_long),
        b_radius: Number(b.b_radius) || 0,
      }));
    } else {
      buildings.value = [];
    }
    nextTick(() => {
      setTimeout(() => {
        updateMapCenter();
        isLoading.value = false;
      }, 300);
    });
  } catch (err) {
    console.error("โหลดอาคาร error:", err);
    isLoading.value = false;
  }
};

const updateMapCenter = async () => {
  const map = mapRef.value?.leafletObject;
  if (!map) return;
  await nextTick();

  if (!buildings.value || buildings.value.length === 0) {
    safeSetView(map, [13.6786, 100.6031], 17);
    setTimeout(() => safeInvalidateSize(map), 300);
    return;
  }

  const coords = buildings.value
    .filter((b) => b && b.b_lat && b.b_long)
    .map((b) => [Number(b.b_lat), Number(b.b_long)])
    .filter(coord => 
      Array.isArray(coord) && coord.length === 2 &&
      !isNaN(coord[0]) && !isNaN(coord[1]) &&
      isFinite(coord[0]) && isFinite(coord[1]) &&
      coord[0] !== 0 && coord[1] !== 0
    );

  if (coords.length === 0) {
    safeSetView(map, [13.6786, 100.6031], 17);
    setTimeout(() => safeInvalidateSize(map), 300);
    return;
  }

  await nextTick();
  setTimeout(() => {
    if (coords.length === 1) {
      safeSetView(map, coords[0], 17);
    } else {
      const latSum = coords.reduce((sum, c) => sum + c[0], 0);
      const lngSum = coords.reduce((sum, c) => sum + c[1], 0);
      const adjustedLat = (latSum / coords.length) + 0.0010;
      const centerLng = lngSum / coords.length;

      let maxDistance = 0;
      for (let i = 0; i < coords.length; i++) {
        for (let j = i + 1; j < coords.length; j++) {
          const d = Math.sqrt(
            Math.pow(coords[i][0] - coords[j][0], 2) + 
            Math.pow(coords[i][1] - coords[j][1], 2)
          );
          if (d > maxDistance) maxDistance = d;
        }
      }

      let zoomLevel = 17;
      if (maxDistance > 0.05) zoomLevel = 13;
      else if (maxDistance > 0.02) zoomLevel = 14;
      else if (maxDistance > 0.01) zoomLevel = 15;
      else if (maxDistance > 0.005) zoomLevel = 16;

      safeSetView(map, [adjustedLat, centerLng], zoomLevel);
    }
    setTimeout(() => safeInvalidateSize(map), 300);
  }, 300);
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

const openEdit = (building) => {
  const latest = buildings.value.find(b => b.b_id === building.b_id);
  editFormData.value = { ...(latest || building) };
  showEditModal.value = true;
};

const saveAdd = async () => {
  try {
    await forRef.value.validate();
    const payload = {
      ...addFormData.value,
      b_name: addFormData.value.b_name.trim(),
      b_address: addFormData.value.b_address.trim(),
      b_lat: String(addFormData.value.b_lat),
      b_long: String(addFormData.value.b_long),
      b_radius: String(addFormData.value.b_radius),
    };
    const res = await axios.put("/building/add_building", payload);
    message.success(res.data.message || "เพิ่มอาคารสำเร็จ");
    showAddModal.value = false;
    await fetchBuildings();
    nextTick(() => {
      const map = mapRef.value?.leafletObject;
      if (map) { safeInvalidateSize(map); updateMapCenter(); }
    });
  } catch (error) {
    message.error(error.response?.data?.message || "เพิ่มอาคารไม่สำเร็จ");
    console.error("เพิ่มอาคาร error:", error);
  }
};

const saveEdit = async () => {
  try {
    const payload = {
      ...editFormData.value,
      b_name: editFormData.value.b_name.trim(),
      b_address: editFormData.value.b_address.trim(),
      b_lat: String(editFormData.value.b_lat),
      b_long: String(editFormData.value.b_long),
      b_radius: String(editFormData.value.b_radius),
    };
    const res = await axios.patch("/building/edit_building", payload);
    message.success(res.data.message || "แก้ไขอาคารสำเร็จ");
    showEditModal.value = false;
    await fetchBuildings();
    nextTick(() => {
      const map = mapRef.value?.leafletObject;
      if (map) { safeInvalidateSize(map); updateMapCenter(); }
    });
  } catch (error) {
    message.error(error.response?.data?.message || "แก้ไขอาคารไม่สำเร็จ กรุณากรอกข้อมูลให้ครบ");
    console.error("แก้ไขอาคาร error:", error);
  }
};

const deleteBuilding = async (b_id) => {
  try {
    const res = await axios.patch("/building/delete_building", { b_id });
    message.success(res.data.message || "ลบอาคารสำเร็จ");
    showEditModal.value = false;
    await fetchBuildings();
    nextTick(() => {
      const map = mapRef.value?.leafletObject;
      if (map) { safeInvalidateSize(map); updateMapCenter(); }
    });
  } catch (err) {
    message.error(err.response?.data?.message || "ลบอาคารไม่สำเร็จ");
    console.error("ลบอาคาร error:", err);
  }
};

const showAddModal = ref(false);
const showEditModal = ref(false);

const addFormData = ref({
  b_name: "", b_address: "",
  b_lat: 13.6786, b_long: 100.6031, b_radius: 50,
});

const editFormData = ref({
  b_id: null, b_name: "", b_address: "",
  b_lat: 13.6786, b_long: 100.6031, b_radius: 50,
});

const onMapClickAdd = async (e) => {
  addFormData.value.b_lat = e.latlng.lat;
  addFormData.value.b_long = e.latlng.lng;
  try {
    const res = await axios.get("https://nominatim.openstreetmap.org/reverse", {
      params: { lat: e.latlng.lat, lon: e.latlng.lng, format: "json", addressdetails: 1 }
    });
    addFormData.value.b_address = res.data.display_name;
  } catch (err) {
    console.error("reverse geocode error:", err);
  }
};

const onMapClickEdit = async (e) => {
  editFormData.value.b_lat = e.latlng.lat;
  editFormData.value.b_long = e.latlng.lng;
  try {
    const res = await axios.get("https://nominatim.openstreetmap.org/reverse", {
      params: { lat: e.latlng.lat, lon: e.latlng.lng, format: "json", addressdetails: 1 }
    });
    editFormData.value.b_address = res.data.display_name;
  } catch (err) {
    console.error("reverse geocode error:", err);
  }
};

const onCircleEdit = (building, e) => building.b_radius = e.target.getRadius();
const onCircleMove = (building, e) => {
  const center = e.target.getLatLng();
  building.b_lat = center.lat;
  building.b_long = center.lng;
};
const onAddCircleEdit = (e) => addFormData.value.b_radius = e.target.getRadius();
const onAddCircleMove = (e) => {
  const center = e.target.getLatLng();
  addFormData.value.b_lat = center.lat;
  addFormData.value.b_long = center.lng;
};
const onEditCircleEdit = (e) => editFormData.value.b_radius = e.target.getRadius();
const onEditCircleMove = (e) => {
  const center = e.target.getLatLng();
  editFormData.value.b_lat = center.lat;
  editFormData.value.b_long = center.lng;
};

const segmentedOptions = [
  {
    label: h("span", [h(CalendarOutlined, { style: "margin-right: 4px;" }), "ตาราง"]),
    value: "table",
  },
  {
    label: h("span", [h(EnvironmentOutlined, { style: "margin-right: 4px;" }), "แผนที่"]),
    value: "map",
  }
];

watch(viewMode, (val) => {
  if (val === "table") {
    router.push("/admin/building");
  } else if (val === "map") {
    router.push("/admin/mapmanagement");
    setTimeout(() => {
      const map = mapRef.value?.leafletObject;
      if (map) { safeInvalidateSize(map); updateMapCenter(); }
    }, 300);
  }
});

onMounted(async () => {
  isLoading.value = true;
  await fetchBuildings();
  nextTick(() => {
    setTimeout(() => {
      const map = mapRef.value?.leafletObject;
      if (map) { safeInvalidateSize(map); updateMapCenter(); }
      isLoading.value = false;
    }, 500);
  });
});
</script>

<style scoped>
.map-page-wrapper {
  width: 100%;
  height: 100%;
  overflow: hidden;
}

.map-page {
  position: relative; 
  top: 0;
  left: 0;
  width: 100%;
  height: calc(100vh - 64px);
  display: flex;
  overflow: hidden;
}

.map-container {
  flex: 1;
  height: 100%;
  margin-left: 280px; 
  z-index: 0;
  transition: margin-left 0.3s ease;
}

.map-container.collapsed-map {
  margin-left: 0px;
}

.sidebar {
  position: absolute; 
  display: flex;
  flex-direction: column;
  top: 0;
  left: 0;
  height: 100%;
  width: 280px;
  background: #ffffff;
  border-right: 1px solid #ddd;
  box-shadow: 2px 0 6px rgba(0,0,0,0.05);
  flex-shrink: 0;              
  transition: transform 0.3s ease; 
  z-index: 3000;
}

.sidebar.collapsed {
  transform: translateX(-280px);
  z-index: 9999;
}

.toolbar-floating {
  position: absolute;
  top: 12px;
  left: 12px;
  right: 12px;
  z-index: 5000;
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 12px;
  padding: 8px 16px;
  border-radius: 8px;
}

.toolbar-right {
  display: flex;
  align-items: center;
}

.toggle-btn {
  position: absolute;
  top: 50%; right: -30px;
  transform: translateY(-50%);
  width: 28px; height: 60px;
  background: white;
  border: 1px solid #ddd;
  border-left: none;
  border-radius: 0 4px 4px 0;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: left 0.3s ease;
  z-index: 9999;
  font-size: 18px;
}

.toggle-btn:hover { background: #f5f5f5; }

.sidebar-header {
  padding: 16px 12px 12px 12px;
  margin-bottom: 12px;
}

.search-input { width: 100%; }

:deep(.search-input .ant-input) { height: 32px; }
:deep(.search-input .ant-btn) { height: 32px; line-height: 32px; }

.building-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 0 8px 60px;
  overflow-y: auto;
  max-height: calc(100vh - 160px);
  width: 100%;
  box-sizing: border-box;
  scrollbar-width: thin;
  scrollbar-color: #ccc transparent;
}

.building-list::-webkit-scrollbar { width: 6px; }
.building-list::-webkit-scrollbar-thumb {
  background-color: rgba(0,0,0,0.2);
  border-radius: 3px;
}

.building-item {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  background: #fafafa;
  padding: 8px 10px;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  width: 100%;
  position: relative;
}

.building-item:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  background-color: #f0f5ff;
}

.beacon-btn {
  position: absolute;
  right: 8px; top: 50%;
  transform: translateY(-50%);
  background: transparent;
  border: none;
  color: #1890ff;
  display: flex;
  align-items: center;
  justify-content: center;
}

.beacon-btn:hover { background: #f0f5ff; color: #40a9ff; }

.building-info {
  display: flex;
  flex-direction: column;
  justify-content: center;
  flex: 1;
}

.building-info .name {
  word-break: break-word;
  white-space: normal;
  overflow-wrap: break-word;
  max-width: 100%;
  line-height: 1.3;
}

.info-row {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
  overflow: hidden;
  padding-right: 40px;
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

:deep(.ant-segmented-item-selected) {
  background-color: #093b69 !important;
  color: white !important;
}

:deep(.ant-segmented-item-selected svg) { color: white !important; }

::v-deep(.leaflet-control-zoom) {
  position: absolute !important;
  bottom: 20px !important;
  right: 20px !important;
  z-index: 1000 !important;
  display: block !important;
}

::v-deep(.leaflet-tooltip) {
  background: transparent !important;
  border: none !important;
  box-shadow: none !important;
}

::v-deep(.leaflet-tooltip::before) { display: none !important; }

::v-deep(.building-tooltip) {
  background-color: #000000 !important;
  color: #ffffff !important;
  font-weight: 600;
  padding: 6px 12px;
  border-radius: 4px;
  font-size: 13px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.3);
}

.map-slider {
  position: absolute;
  top: 330px; right: 1px;
  height: 30px;
  background: white;
  padding: 8px;
  border-radius: 8px;
  box-shadow: 0 2px 6px rgba(0,0,0,0.2);
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
  scroll-behavior: smooth;
}

:deep(.scrollable-modal .ant-modal-body::-webkit-scrollbar) { width: 8px; }
:deep(.scrollable-modal .ant-modal-body::-webkit-scrollbar-thumb) {
  background-color: #c1c1c1;
  border-radius: 8px;
}

:global(body.ant-scrolling-effect) {
  overflow: hidden !important;
  height: 100vh !important;
}

:global(.ant-modal-wrap) { overflow: hidden !important; }
</style>