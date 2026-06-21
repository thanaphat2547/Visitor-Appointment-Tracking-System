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
              placeholder="ค้นหา ผู้มาติดต่อ..."
              size="large"
            />

            <div class="today-label">
              <CalendarOutlined /> รายการนัดหมายวันนี้
            </div>
          </div>

          <!-- Booking List -->
          <div class="booking-list" v-if="!collapsed">
  <div
    v-for="bk in filteredBookings"
    :key="bk.bk_id"
    class="booking-card"
    :class="getStatusTheme(bk.bk_status).class"
    @click="focusVisitor(bk)"
  >
    <div class="card-content-wrapper">
      <div class="details-section">
        
        <div class="detail-item name-highlight-row">
          <UserOutlined class="detail-icon" />
          <span class="detail-label">ผู้ติดต่อ:</span>
          <span class="detail-value name-text">{{ bk.visitor_name }}</span>
        </div>

        <div class="detail-item">
          <TeamOutlined class="detail-icon" />
          <span class="detail-label">พนักงาน:</span>
          <span class="detail-value">{{ bk.employee_name }}</span>
        </div>

        <div class="detail-item">
          <FileTextOutlined class="detail-icon" />
          <span class="detail-label">หัวข้อ:</span>
          <span class="detail-value text-ellipsis">{{ bk.purpose || '-' }}</span>
        </div>

        <div class="detail-item">
          <ClockCircleOutlined class="detail-icon" />
          <span class="detail-label">เวลานัด:</span>
          <span class="detail-value time-highlight">
            {{ dayjs(bk.appointment_start).format("HH:mm") }} - {{ dayjs(bk.appointment_end).format("HH:mm") }} น.
          </span>
        </div>

        <div class="detail-item">
          <InfoCircleOutlined class="detail-icon" />
          <span class="detail-label">สถานะ:</span>
          <span class="custom-status-tag" :class="getStatusTheme(bk.bk_status).tagClass">
            {{ getStatusTheme(bk.bk_status).text }}
          </span>
        </div>
        
      </div>
    </div>
  </div>
  
  <a-empty v-if="filteredBookings.length === 0" description="ไม่มีรายการนัดหมายวันนี้" />
</div>

          <!-- Sidebar Footer -->
          <div class="sidebar-footer">
            <div class="update-info"> 
              <span>อัปเดตล่าสุด : <b>{{ lastUpdateTime || '-' }}</b></span> 
              <span>| รีเฟรชใน <b>{{ countdown }}</b> วิ</span>
            </div>
            <span
              class="refresh-icon"
              @click="manualRefresh"
              :class="{ spinning: isRefreshing }"
              title="คลิกเพื่อรีเฟรชข้อมูล"
            >
              <SyncOutlined />
            </span>
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

        <!-- Map -->
        <div class="map-container" :class="{ 'collapsed-map': collapsed }">
          <l-map
            ref="mapRef"
            style="height: 100%; width: 100%"
            :zoom="17"
            :center="[13.6793, 100.6031]"
            @ready="onMapReady"
          >
            <l-tile-layer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
            <l-control-zoom position="bottomright" />

            <!-- Marker อาคาร -->
            <l-marker
              v-for="b in buildings"
              :key="b.b_id"
              :lat-lng="[b.b_lat, b.b_long]"
              @click="openView(b)"
            >
              <l-tooltip class="building-tooltip" :options="{ permanent: true, direction: 'top', offset: [-15, 0] }">
               อาคาร : {{ b.b_name }}
              </l-tooltip>
            </l-marker>

             <l-circle
              v-for="b in buildings"
              :key="'circle-' + b.b_id"
              :lat-lng="[b.b_lat, b.b_long]"
              :radius="b.b_radius"
              color="blue"
            />      

            <!-- Marker Beacon -->
            <l-marker
              v-for="bc in validBeacons"
              :key="'beacon-' + bc.bc_id"
              :lat-lng="[bc.bc_lat, bc.bc_long]"
              :icon="beaconIcon"
              :ref="el => registerMarker(el, bc.bc_id)"
            >
              <l-tooltip class="beacon-tooltip" :options="{ permanent: true, direction: 'top', offset: [0, 0] }">
                {{ bc.bc_name }}
              </l-tooltip>
            </l-marker>

            <l-marker
              v-for="loc in visitorLocations"
              :key="'vis-' + (loc.vis_id || loc.id || Math.random())"
              :lat-lng="[loc.loc_lat, loc.loc_long]"
              :icon="visitorIcon"
            >
              <l-tooltip :options="{ permanent: true, direction: 'top', className: 'visitor-custom-tooltip', offset: [0, -15] }">
                <div class="visitor-marker-content" :class="(loc.status || 'IN').toUpperCase() === 'OUT' ? 'out' : 'in'">
                  <div style="font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 120px;">
                    {{ loc.visitor_name || loc.vis_id || loc.bk_id || loc.building_name || loc.b_name || 'Unknown' }}
                  </div>
                  <div style="font-size: 10px; opacity: 0.88; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 120px; margin-top: 2px;">
                    {{ loc.building_name || loc.b_name || findBuildings(loc.loc_lat, loc.loc_long) || 'ไม่ทราบอาคาร' }}
                  </div>
                </div>
              </l-tooltip>
            </l-marker>
          </l-map>
        </div>

        <!-- Modal -->
        <a-modal 
          v-model:open="showViewModal" 
          title="ข้อมูลอาคาร" 
          :footer="null"
          :style="{ top: '80px' }"
        >
          <a-descriptions bordered :column="1">
            <a-descriptions-item label="ชื่ออาคาร">{{ String(formData.b_name) }}</a-descriptions-item>
            <a-descriptions-item label="ที่อยู่">{{ String(formData.b_address) }}</a-descriptions-item>
            <a-descriptions-item label="ละติจูด">{{ Number(formData.b_lat).toFixed(6) }}</a-descriptions-item>
            <a-descriptions-item label="ลองจิจูด">{{ Number(formData.b_long).toFixed(6) }}</a-descriptions-item>
            <a-descriptions-item label="ขอบเขตของอาคาร (เมตร)">{{ Number(formData.b_radius) }}</a-descriptions-item>
          </a-descriptions>

          <div style="margin-top: 16px">
            <l-map style="height: 170px" :zoom="17" :center="[formData.b_lat, formData.b_long]">
              <l-tile-layer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
              <l-marker :lat-lng="[formData.b_lat, formData.b_long]" />
              <l-circle :lat-lng="[formData.b_lat, formData.b_long]" :radius="formData.b_radius" color="blue" />
            </l-map>
          </div>
        </a-modal>

      </div>
    </div>
  </a-spin>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed, nextTick, watch } from "vue";
import axios from "@/axios";
import { message } from "ant-design-vue";
import { useRouter } from "vue-router";
import L from "leaflet";
import { LMap, LTileLayer, LMarker, LCircle, LTooltip , LControlZoom } from "@vue-leaflet/vue-leaflet";
import "leaflet/dist/leaflet.css";
import iconUrl from 'leaflet/dist/images/marker-icon.png';
import iconRetinaUrl from 'leaflet/dist/images/marker-icon-2x.png';
import shadowUrl from 'leaflet/dist/images/marker-shadow.png';
import { 
  DoubleLeftOutlined, 
  DoubleRightOutlined, 
  ClockCircleOutlined, 
  SyncOutlined,
  UserOutlined,          
  TeamOutlined,   
  InfoCircleOutlined,    
  FileTextOutlined,
  CalendarOutlined      
} from "@ant-design/icons-vue";
import * as turf from '@turf/turf';
import dayjs from "dayjs";

// Fix Leaflet marker icons
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl,
  iconRetinaUrl,
  shadowUrl,
});

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


const router = useRouter();
const mapRef = ref(null);
const buildings = ref([]);
const beacons = ref([]);
const searchValue = ref("");
const isLoading = ref(true)
const userMovedMap = ref(false);
const countdown = ref(15);
const lastUpdateTime = ref(null);
let countdownTimer = null;
const bookings = ref([]);
const isRefreshing = ref(false);
const dayjsFunc = dayjs;
const visitorLocations = ref([]);

const fetchVisitorLocations = async () => {
  try {
    const res = await axios.get("/location_beacon/show_location_beacon");
    const rawData = res.data.data || res.data;
    if (Array.isArray(rawData)) {
      visitorLocations.value = rawData.filter(item => {
        const timeStr = item.lobc_time_in || item.updated_at || item.created_at;
        if (!timeStr) return true;
        const time = dayjs(timeStr);
        return dayjs().diff(time, 'hour') <= 24;
      }).map(item => ({
        ...item,
        loc_lat: item.loc_lat != null ? Number(item.loc_lat) : null,
        loc_long: item.loc_long != null ? Number(item.loc_long) : null
      })).filter(item => item.loc_lat != null && item.loc_long != null);
    }
  } catch (error) {
    console.error("Fetch Visitor Error:", error);
  }
};

const manualRefresh = async () => {
  console.log("clicked");
  try {
    isRefreshing.value = true;
    isLoading.value = true;

    // โหลดข้อมูลใหม่ ทั้ง Beacon, อาคาร และ Booking
    await Promise.all([
      fetchBeacons(),
      fetchBuildings(),
      fetchTodayBookings(),
      fetchVisitorLocations(),
    ]);

    // ตั้งเวลาอัปเดตใหม่
    const now = new Date();
    lastUpdateTime.value = now.toLocaleString("th-TH", {
      dateStyle: "short",
      timeStyle: "medium",
    });

    // รีเซ็ต countdown
    countdown.value =15;

    // เก็บค่าไว้ใน localStorage ด้วย
    localStorage.setItem("mapCountdown", countdown.value);
    localStorage.setItem("mapLastUpdateTime", lastUpdateTime.value);

  } catch (err) {
    console.error("Manual refresh failed:", err);
  } finally {
    isLoading.value = false;
    isRefreshing.value = false;
  }
};

const visitorIcon = L.icon({
  iconUrl: new URL('@/assets/Icon_Visitor.png', import.meta.url).href,
  iconSize: [35, 35],
  iconAnchor: [17, 35],
});

const onMapReady = () => {
  setTimeout(() => {
    const map = mapRef.value?.leafletObject;
    if (map) safeInvalidateSize(map);
  }, 300);
  
  const map = mapRef.value?.leafletObject;
  if (map) {
    map.on('movestart', () => {
      userMovedMap.value = true;
    });
    map.on('zoomstart', () => {
      userMovedMap.value = true;
    });
  }
};


const markerRefs = ref({});
const activeMarkerId = ref(null);

function registerMarker(el, id) {
  if (!id) return;
  const key = String(id);
    if (!el) {
    if (markerRefs.value[key]) {
      try { markerRefs.value[key].leafletObject?.setZIndexOffset(0); } catch (e) { console.debug('marker cleanup error', e); }
    }
    delete markerRefs.value[key];
    return;
  }
  markerRefs.value[key] = el;
}

const props = defineProps({
  isSiderCollapsed: Boolean
})

const collapsed = ref(props.isSiderCollapsed);

const emit = defineEmits(['update:isSiderCollapsed']);

watch(() => props.isSiderCollapsed, (val) => {
  collapsed.value = val
  nextTick(() => {
    setTimeout(() => {
      const map = mapRef.value?.leafletObject;
      if (map) safeInvalidateSize(map);
    }, 300)
  })
})

const toggleSidebar = () => {
  collapsed.value = !collapsed.value;
  emit('update:isSiderCollapsed', collapsed.value);

  nextTick(() => {
    setTimeout(() => {
      const map = mapRef.value?.leafletObject;
      if (map && map._container) {
        safeInvalidateSize(map);
      }
    }, 350) 
  })
}

watch(() => props.isSiderCollapsed, (newVal) => {
  collapsed.value = newVal;
});

// MODAL
const showViewModal = ref(false);
const formData = ref({
  b_name: "",
  b_address: "",
  b_lat: 13.6786,
  b_long: 100.6031,
  b_radius: 50,
});

// หาว่า Beacon อยู่อาคารไหน
const findBuildings = (lat, long) => {
  const b = buildings.value.find(
    (b) => L.latLng(lat, long).distanceTo([b.b_lat, b.b_long]) <= b.b_radius
  );
  return b ? b.b_name : "ไม่ทราบอาคาร";
};

// ดึง Beacons แสดงทั้งหมด
const fetchBeacons = async () => {
  try {
    const toArray = (res) => {
      if (!res) return [];
      if (Array.isArray(res)) return res;
      if (Array.isArray(res.data)) return res.data;
      if (Array.isArray(res.data?.data)) return res.data.data;
      if (Array.isArray(res.data?.rows)) return res.data.rows;
      return [];
    };

    // ดึงข้อมูลตำแหน่งปัจจุบัน (เฉพาะคนที่ยังอยู่ในพื้นที่)
    const resLoc = await axios.get("/location_beacon/show_location_beacon");
    const locs = toArray(resLoc);

    // ดึงรายชื่อ Beacon ทั้งหมดในระบบ
    const resAll = await axios.get("/beacon/show_beacon");
    const allBeacons = toArray(resAll);

    // สร้าง Map สำหรับค้นหาตำแหน่งตาม bc_id
    const locById = {};
    locs.forEach((l) => {
      if (l && l.bc_id) {
        locById[String(l.bc_id)] = l;
      }
    });

    const fmtDateTime = (iso) => {
      if (!iso) return null;
      try {
        return new Date(iso).toLocaleString("th-TH", {
          dateStyle: "short",
          timeStyle: "short",
        });
      } catch (e) {
        return String(iso);
      }
    };

    // รวมข้อมูล Beacon และ Location เพื่อนำไปแสดงผลบนแผนที่
    beacons.value = allBeacons.map((b) => {
      const bId = b.bc_id || b.id;
      const loc = locById[String(bId)] || null;

      // ใช้พิกัดจาก tb_location (loc_lat) ถ้าไม่มีให้ใช้ค่าเริ่มต้นจาก tb_beacon (bc_lat)
      const latitude = loc?.loc_lat ?? b.bc_lat ?? null;
      const longitude = loc?.loc_long ?? b.bc_long ?? null;

      const rawIn = loc?.lobc_time_in || null;
      const rawOut = loc?.lobc_time_out || null;

      let statusType = "unknown";
      let statusText = "ยังไม่พบการเข้าออก";

      // กำหนดสถานะตามข้อมูลเวลา
      if (rawOut) {
        statusType = "out";
        statusText = `ออกเมื่อ ${fmtDateTime(rawOut)}`;
      } else if (rawIn) {
        statusType = "in";
        statusText = `เข้าเมื่อ ${fmtDateTime(rawIn)}`;
      }

      const name = b.bc_name || b.name || "-";
      
      // ค้นหาชื่ออาคารจากพิกัด (ถ้าใน loc ไม่มี b_name)
      const computedBuildingName = loc?.b_name || (latitude && longitude ? findBuildings(Number(latitude), Number(longitude)) : "-");

      return {
        bc_id: bId,
        bc_name: name,
        bc_lat: latitude != null ? Number(latitude) : null,
        bc_long: longitude != null ? Number(longitude) : null,
        buildingName: computedBuildingName,
        statusType,
        statusText,
        raw_time_in: rawIn,
        raw_time_out: rawOut,
        lastEventTime: rawOut ? new Date(rawOut).getTime() : (rawIn ? new Date(rawIn).getTime() : 0),
      };
    });

    if (!beacons.value.some(b => b.bc_lat !== null) && locs.length > 0) {
      beacons.value = locs.map((loc) => {
        const rawIn = loc.lobc_time_in || null;
        const rawOut = loc.lobc_time_out || null;
        
        return {
          bc_id: loc.bc_id,
          bc_name: loc.bc_name || "ไม่ทราบชื่อ",
          bc_lat: loc.loc_lat != null ? Number(loc.loc_lat) : null,
          bc_long: loc.loc_long != null ? Number(loc.loc_long) : null,
          buildingName: loc.b_name || "-",
          statusType: rawOut ? 'out' : (rawIn ? 'in' : 'unknown'),
          statusText: rawOut ? `ออกเมื่อ ${fmtDateTime(rawOut)}` : `เข้าเมื่อ ${fmtDateTime(rawIn)}`,
          raw_time_in: rawIn,
          raw_time_out: rawOut,
          lastEventTime: rawOut ? new Date(rawOut).getTime() : (rawIn ? new Date(rawIn).getTime() : 0),
        };
      });
    }

    console.log("✅ Update Beacons data success");

  } catch (err) {
    console.error("❌ โหลด Beacon error:", err);
  }
};

const fetchTodayBookings = async () => {
  try {
    const auth = localStorage.getItem("auth");
    const headers = { Authorization: `Basic ${auth}` };
    const todayStr = dayjs().format('YYYY-MM-DD');
    const res = await axios.get("/booking/show_booking", { 
      headers,
      params: { 
        startDate: todayStr, 
        endDate: todayStr 
      } 
    });

    const rawData = res.data.data || res.data;
    
    if (Array.isArray(rawData)) {
      bookings.value = rawData.filter(item => 
        dayjs(item.appointment_start).format('YYYY-MM-DD') === todayStr
      );
    }
  } catch (error) {
    console.error("Fetch Today Bookings Error:", error);
  }
};

// --- ระบุสีและไอคอนตามสถานะ ---
const getStatusTheme = (status) => {
  const key = String(status);
  const themes = {
    '0': { color: '#3498db', text: 'รอดำเนินการ', class: 'status-pending', tagClass: 'tag-pending' },
    '1': { color: '#2ecc71', text: 'มาถึงแล้ว', class: 'status-in', tagClass: 'tag-success' },
    '2': { color: '#13c2c2', text: 'เสร็จสิ้น', class: 'status-finished', tagClass: 'tag-finished' },
    '3': { color: '#f39c12', text: 'เกินกำหนดนัด', class: 'status-late', tagClass: 'tag-late' },
    '4': { color: '#e74c3c', text: 'ยกเลิก', class: 'status-cancel', tagClass: 'tag-error' }
  };
  return themes[key] || themes['0'];
};

const filteredBookings = computed(() => {
  let list = [...bookings.value];

  if (searchValue.value) {
    const search = searchValue.value.toLowerCase();
    list = list.filter(bk => 
      bk.visitor_name.toLowerCase().includes(search) ||
      (bk.building_name && bk.building_name.toLowerCase().includes(search))
    );
  }

  return list.sort((a, b) => dayjs(a.appointment_start).unix() - dayjs(b.appointment_start).unix());
});

// ดึง อาคาร  
const fetchBuildings = async () => {
  try {
    isLoading.value = true;
    const res = await axios.get("/building/show_building");
    const rawData = res.data.data || res.data;

    if (Array.isArray(rawData)) {
      buildings.value = rawData
        .map((b) => ({
          ...b,
          b_lat: Number(b.b_lat),
          b_long: Number(b.b_long),
          b_radius: Number(b.b_radius) || 0,
        }))
        .filter(b => b.b_lat && b.b_long); 
    }

    await nextTick();
    
    setTimeout(() => {
      const map = mapRef.value?.leafletObject;
      if (map && map._loaded && map.getContainer() && map.getPane('mapPane')) { 
        try {
          safeInvalidateSize(map); 
          if (buildings.value.length > 0 && !userMovedMap.value) {
            updateMapCenter();
          }
        } catch (e) {
          console.warn("Leaflet is not ready for invalidateSize", e);
        }
      }
      isLoading.value = false;
    }, 600);

  } catch (err) {
    console.error("โหลดอาคาร error:", err);
    isLoading.value = false;
  }
};

// เปิด modal อาคาร
const openView = (building) => {
  formData.value = { ...building };
  showViewModal.value = true;
};

//  ฟังก์ชันเช็คว่า beacon อยู่ในรัศมีอาคารหรือไม่
function isInsideAnyBuilding(lat, lng) {
  for (const b of buildings.value) {
    if (!b.b_lat || !b.b_long || !b.b_radius) continue;

    const beaconPoint = turf.point([lng, lat]);
    const buildingCenter = turf.point([b.b_long, b.b_lat]);
    const distance = turf.distance(beaconPoint, buildingCenter, { units: 'meters' });

    if (distance <= b.b_radius) {
      return true;
    }
  }
  return false;
}

const validBeacons = computed(() =>
  beacons.value.filter((bc) => 
    bc.bc_lat && 
    bc.bc_long && 
    bc.statusType !== 'out' &&
    isInsideAnyBuilding(bc.bc_lat, bc.bc_long)
  )
);

const filteredBeacons = computed(() => {
  let list = [...beacons.value];

  // เรียงจากเวลาเข้า (ล่าสุด -> เก่าสุด)
  list.sort((a, b) => {
    const timeA = a.lastEventTime || 0;
    const timeB = b.lastEventTime || 0;
    return timeB - timeA;
  });


  if (searchValue.value) {
    list = list.filter((bc) => 
      bc.bc_name.toLowerCase().includes(searchValue.value.toLowerCase())
    );
  }

  return list;
});

const focusVisitor = (bk) => {
  const map = mapRef.value?.leafletObject;
  if (!map || !map._container) return;
  
  if (bk.lobc_lat && bk.lobc_long) {
    safeSetView(map, [bk.lobc_lat, bk.lobc_long], 18);
    userMovedMap.value = true;
  } 
  // ถ้ายังไม่มา ให้ไปที่พิกัดอาคารที่นัดไว้
  else if (bk.b_lat && bk.b_long) {
    safeSetView(map, [bk.b_lat, bk.b_long], 18);
    userMovedMap.value = true;
  }
};

// Focus ไปที่ Beacon
const focusBeacon = (bc) => {
  if (bc.statusType === 'out') {
    message.warning(`พนักงาน ${bc.bc_name} ได้ออกจากอาคารแล้ว`);
    return;
  }

  if (bc.statusType === 'unknown') {
    message.info(`ยังไม่พบการเข้าออกของพนักงาน ${bc.bc_name}`);
    return;
  }
  const map = mapRef.value?.leafletObject;
  if (map) {
    safeSetView(map, [bc.bc_lat, bc.bc_long], 18);
    userMovedMap.value = true;
  }

  const id = bc?.bc_id ?? bc?.id ?? bc?.beacon_id ?? null;
  if (!id) return;

  const key = String(id);

  if (activeMarkerId.value && activeMarkerId.value !== key) {
    const prev = markerRefs.value[activeMarkerId.value];
    if (prev?.leafletObject) {
      try {
        prev.leafletObject.setZIndexOffset(0);

      } catch (e) { /* ignore */ }
    }
  }

  const markerComp = markerRefs.value[key];
  if (markerComp?.leafletObject) {
    try {
      markerComp.leafletObject.setZIndexOffset(1000);
      if (typeof markerComp.leafletObject.bringToFront === 'function') markerComp.leafletObject.bringToFront();
      try {
        const tooltip = markerComp.leafletObject.getTooltip ? markerComp.leafletObject.getTooltip() : markerComp.leafletObject._tooltip;
        if (tooltip) {
          if (typeof tooltip.setLatLng === 'function') {
            tooltip.setLatLng(markerComp.leafletObject.getLatLng());
          }

          if (typeof markerComp.leafletObject.openTooltip === 'function') markerComp.leafletObject.openTooltip();

          const container = tooltip._container || (typeof tooltip.getElement === 'function' ? tooltip.getElement() : null);
          if (container && container.classList) {
            container.classList.add('focused-tooltip');
            container.style.zIndex = '10050';
          }
        }
      } catch (e) {
        console.debug('tooltip focus error', e);
      }

      try {
        const iconEl = markerComp.leafletObject._icon || (typeof markerComp.leafletObject.getElement === 'function' ? markerComp.leafletObject.getElement() : null);
        if (iconEl && iconEl.classList) {
          iconEl.classList.add('focused-marker');
          iconEl.style.zIndex = '10060';
        }
      } catch (e) {
        console.debug('marker icon focus error', e);
      }
    } catch (e) { /* ignore */ }
  }

  if (activeMarkerId.value && activeMarkerId.value !== key) {
    const prev = markerRefs.value[activeMarkerId.value];
    try {
      const t = prev?.leafletObject?.getTooltip ? prev.leafletObject.getTooltip() : prev?.leafletObject?._tooltip;
      const prevContainer = t?._container || (t && typeof t.getElement === 'function' ? t.getElement() : null);
      if (prevContainer && prevContainer.classList) {
        prevContainer.classList.remove('focused-tooltip');
        prevContainer.style.zIndex = '';
      }
      try {
        const prevIcon = prev?.leafletObject?._icon || (prev?.leafletObject && typeof prev.leafletObject.getElement === 'function' ? prev.leafletObject.getElement() : null);
        if (prevIcon && prevIcon.classList) {
          prevIcon.classList.remove('focused-marker');
          prevIcon.style.zIndex = '';
        }
      } catch (err) {
        console.debug('prev icon reset error', err);
      }

      prev?.leafletObject?.setZIndexOffset(0);
      if (typeof prev?.leafletObject?.bringToBack === 'function') prev.leafletObject.bringToBack();
    } catch (err) {
      console.debug('reset prev tooltip error', err);
    }
  }

  activeMarkerId.value = key;
};

// ปรับ center ของแผนที่ 
const updateMapCenter = async () => {
  const map = mapRef.value?.leafletObject;

  if (!map || !map._container || userMovedMap.value) {
      return;
  }

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
      Array.isArray(coord) && 
      coord.length === 2 && 
      !isNaN(coord[0]) && 
      !isNaN(coord[1]) &&
      isFinite(coord[0]) && 
      isFinite(coord[1]) &&
      coord[0] !== 0 &&
      coord[1] !== 0
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
      const latSum = coords.reduce((sum, coord) => sum + coord[0], 0);
      const lngSum = coords.reduce((sum, coord) => sum + coord[1], 0);
      const centerLat = latSum / coords.length;
      const centerLng = lngSum / coords.length;
      const adjustedLat = centerLat + 0.0010;
      
      let maxDistance = 0;
      for (let i = 0; i < coords.length; i++) {
        for (let j = i + 1; j < coords.length; j++) {
          const distance = Math.sqrt(
            Math.pow(coords[i][0] - coords[j][0], 2) + 
            Math.pow(coords[i][1] - coords[j][1], 2)
          );
          if (distance > maxDistance) maxDistance = distance;
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

const reloadData = async () => {
  try {
    isLoading.value = true;
    
    await Promise.all([
      fetchBuildings(),
      fetchTodayBookings(),
      fetchVisitorLocations(),
    ]);
  
    await nextTick();
    
    const now = new Date();
    lastUpdateTime.value = now.toLocaleString("th-TH", {
      dateStyle: "short",
      timeStyle: "medium",
    });

    countdown.value = 15;
    localStorage.setItem("mapCountdown", countdown.value);
    localStorage.setItem("mapLastUpdateTime", lastUpdateTime.value);
  } catch (error) {
    console.error("Reload data error:", error);
  } finally {
    isLoading.value = false;
  }
};

function startCountdownTimer() {

  if (countdownTimer) clearInterval(countdownTimer);

  countdownTimer = setInterval(async () => {
    countdown.value--;

    localStorage.setItem("mapCountdown", countdown.value);

    if (countdown.value <= 0) {
      clearInterval(countdownTimer);
      await reloadData();
      startCountdownTimer();
    }
  }, 1000);
}

onMounted(async () => {
  // ดึงค่าเดิมจาก LocalStorage (ถ้ามี)
  const savedCountdown = parseInt(localStorage.getItem('mapCountdown')) || 15;
  const savedLastUpdate = localStorage.getItem('mapLastUpdateTime') || null;

  countdown.value = savedCountdown;
  lastUpdateTime.value = savedLastUpdate;
  collapsed.value = props.isSiderCollapsed;
  isLoading.value = true;

  // รอให้ DOM และ Map พร้อมใช้งาน
  await nextTick();  
  await new Promise(resolve => setTimeout(resolve, 500));
  
  const map = mapRef.value?.leafletObject;
  if (map) {
    map.zoomControl?.remove(); 
    L.control.zoom({ position: "bottomright" }).addTo(map);
  }

  try {
    // โหลดข้อมูล "อาคาร" และ "นัดหมายวันนี้" พร้อมกัน
    await Promise.all([
      fetchBuildings(),
      fetchTodayBookings(),
      fetchVisitorLocations()
    ]);
  } catch (error) {
    console.error("Initial load error:", error);
    message.error("ไม่สามารถโหลดข้อมูลเริ่มต้นได้");
  }

  // จัดการ Layout แผนที่ให้พอดีกับข้อมูลที่โหลดมา
  nextTick(() => {
    setTimeout(() => {
      const mapObj = mapRef.value?.leafletObject;
      if (mapObj) {
        safeInvalidateSize(mapObj); // รีเฟรชขนาดแผนที่ให้เต็มพื้นที่
        updateMapCenter();       // เลื่อนแผนที่ไปรวมจุดกึ่งกลางอาคาร
      }
      isLoading.value = false;   // ปิดหน้าจอโหลด
    }, 300);
  });

  // เริ่มตัวนับเวลาถอยหลังเพื่อ Auto Refresh
  startCountdownTimer();
});

onUnmounted(() => {
  if (countdownTimer) clearInterval(countdownTimer);
});

</script>

<style scoped>

.booking-card {
  margin: 10px 12px;
  background: #ffffff;
  border-radius: 12px;
  padding: 14px;
  border: 1px solid #f0f0f0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  cursor: pointer;
  transition: all 0.2s ease;
}

.booking-card:hover {
  border-color: #1890ff;
  box-shadow: 0 4px 12px rgba(24, 144, 255, 0.1);
}

.visitor-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
}

.divider {
  height: 1px;
  background: #f5f5f5;
  margin-bottom: 12px;
}

.details-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.detail-item {
  display: flex;
  align-items: center; 
  font-size: 13px;
  line-height: 1.2;
}

.detail-icon {
  width: 16px;
  margin-right: 10px;
  color: #595959;
  font-size: 14px;
  flex-shrink: 0;
}

.detail-label {
  color: #303030;
  width: 65px; 
  flex-shrink: 0;
}

.detail-value {
  color: #303030;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.name-text {
  font-weight: 500;
  color: #595959;
}

.time-highlight {
  color: #595959;
  font-weight: 600;
}

.text-ellipsis {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.custom-status-tag {
  padding: 1px 10px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
  border: 1px solid transparent;
}

.tag-pending { background: #e6f7ff; color: #1890ff; border-color: #91d5ff; }
.tag-success { background: #f6ffed; color: #52c41a; border-color: #b7eb8f; }
.tag-late { background: #fff7e6; color: #fa8c16; border-color: #ffd591; }
.tag-error { background: #fff1f0; color: #f5222d; border-color: #ffa39e; }
.tag-finished { background: #e6fffb; color: #13c2c2; border-color: #87e8de; }

.booking-card.status-late {
  background: #fffaf0;
  border: 1.5px solid #f39c12;
}

.booking-card.status-finished {
  background: #e6fffb;
  border: 1.5px solid #13c2c2;
}

.tag-error {
  background: #fff1f0;
  color: #f5222d;
}

.visitor-name {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.booking-card {
  margin: 12px;
  background: #ffffff;
  border-radius: 16px;
  padding: 16px;
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.05);
  transition: all 0.3s ease;
  cursor: pointer;
  border: 1px solid transparent;
}

.booking-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.1);
}

.booking-card.status-in {
  background: #f0fdf4;
  border: 1.5px solid #2ecc71;
}

.booking-card.status-pending {
  background: #f0f7ff; /* ฟ้าอ่อน */
  border: 1.5px solid #3498db;
}

.booking-card.status-cancel {
  border-color: #ff4d4f !important;
  background: #fff1f0 !important;   
}

.visitor-name {
  font-size: 17px;
  font-weight: 800;
  color: #2c3e50;
  margin-bottom: 4px;
}

.status-tag {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
}

.tag-success {
  background: #d1fae5;
  color: #059669;
}

.tag-pending {
  background: #dbeafe;
  color: #2563eb;
}

.sidebar-header {
  padding: 16px 15px 10px 15px;
  background: #fff;
  border-bottom: 1px solid #eee;
}

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

.toggle-btn {
  position: absolute;
  top: 50%;
  right: -30px;
  transform: translateY(-50%);
  width: 28px;
  height: 60px;
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

.toggle-btn:hover {
  background: #f5f5f5;
}

.sidebar.collapsed ~ .toggle-btn {
  left: 0;
}

.sidebar-header {
  padding: 16px 12px 12px 12px;
  margin-bottom: 12px;
}

.search-input {
  width: 100%;
  margin-bottom: 15px;
}

.today-label {
  font-size: 14px;
  font-weight: 700;
  color: #595959;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 5px 0;
  margin-bottom: 10px;
}

:deep(.search-input .ant-input) {
  height: 32px;
}

:deep(.search-input .ant-btn) {
  height: 32px;
  line-height: 32px;
}

.booking-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: calc(100vh - 220px); 
  overflow-y: auto;
  padding: 0 8px;
  scrollbar-width: thin;
  scrollbar-color: #ccc transparent;
}

.booking-list::-webkit-scrollbar {
  width: 6px;
}

.booking-list::-webkit-scrollbar-thumb {
  background-color: rgba(0,0,0,0.2);
  border-radius: 3px;
}

.info-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.status-block {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-top: 6px;
}

.status-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.status-text {
  font-size: 12px;
  color: #444;
  font-weight: 600;
}

.building-line {
  font-size: 12px;
  color: #444;
  margin-left: 18px; 
  font-weight: 600;
}

.icon-row {
  display: flex;
  align-items: center;
  margin-top: 6px;
  gap: 6px;
}

.icon-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 6px;
  background: #f0f0f0;
  cursor: pointer;
  transition: background 0.3s;
}

.icon-button:hover {
  background: #1890ff;
}

.icon-button:hover svg {
  color: white;
}

.icon-button svg {
  font-size: 16px;
  color: #555;
}

.sidebar-footer {
  margin-top: auto;
  padding: 10px 14px;
  border-top: 1px solid #eee;
  background: #fafafa;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.update-info {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  line-height: 1.4;
  font-size: 12px;
  color: #444;
}

.update-info span {
  white-space: nowrap;
}

.update-info b {
  color: #555;
}

.refresh-icon {
  font-size: 18px;
  color: #444;
  cursor: pointer;
  transition: transform 0.2s ease, color 0.3s ease;
}

.refresh-icon:hover {
  color: #2e2e2e;
  transform: rotate(25deg);
}

.refresh-icon.spinning {
  animation: spin 1s linear infinite;
  color: #2e2e2e;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.sidebar.collapsed .sidebar-footer {
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.sidebar.collapsed .update-info {
  align-items: center;
}

.active-tooltip {
  background-color: #1890ff !important;
  color: #ffffff !important;
  font-weight: 700 !important;
  font-size: 15px !important;
  padding: 8px 14px !important;
  border-radius: 6px !important;
  box-shadow: 0 4px 16px rgba(24, 144, 255, 0.4) !important;
  border: 2px solid #ffffff !important;
  transition: all 0.3s ease;
  z-index: 10000 !important;
}

.focused-tooltip {
  background-color: #1890ff !important;
  color: #ffffff !important;
  font-weight: 700 !important;
  font-size: 15px !important;
  padding: 8px 14px !important;
  border-radius: 6px !important;
  box-shadow: 0 4px 16px rgba(24, 144, 255, 0.4) !important;
  border: 2px solid #ffffff !important;
  transition: all 0.3s ease;
  z-index: 10000 !important;
}

.focused-marker {
  filter: drop-shadow(0 0 8px rgba(24, 144, 255, 0.8)) 
          drop-shadow(0 0 16px rgba(24, 144, 255, 0.4));
  transition: all 0.3s ease;
  z-index: 10000 !important;
}

::v-deep(.leaflet-tooltip) {
  background: transparent !important;
  border: none !important;
  box-shadow: none !important;
}

::v-deep(.leaflet-tooltip::before) {
  display: none !important;
}

::v-deep(.building-tooltip) {
  background-color: #000000 !important;
  color: #ffffff !important;
  font-weight: 600;
  padding: 4px 8px;
  border-radius: 4px;
}

::v-deep(.beacon-tooltip) {
  background-color: #ffffff !important;
  color: #000000 !important;
  font-weight: 600;
  padding: 4px 8px;
  border-radius: 4px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
  transition: all 0.3s ease;
}

::v-deep(.leaflet-control-zoom) {
  position: absolute !important;
  bottom: 20px !important; 
  right: 20px !important;  
  z-index: 1000 !important;
  display: block !important;
}

@media screen and (max-width: 600px) {
  .sidebar {
    width: 250px;
  }
  
  .map-container {
    margin-left: 250px;
  }
  
  .sidebar-header {
    padding: 16px 8px 8px 8px;
  }
}

::v-deep(.leaflet-tooltip.visitor-custom-tooltip) {
  background-color: transparent !important;
  border: none !important;
  box-shadow: none !important;
  padding: 0 !important;
}

::v-deep(.leaflet-tooltip.visitor-custom-tooltip::before) {
  display: none !important;
}

.visitor-marker-content {
  padding: 4px 8px;
  border-radius: 8px;
  color: white;
  font-size: 11px;
  font-weight: 600;
  box-shadow: 0 2px 6px rgba(0,0,0,0.3);
  text-align: center;
  white-space: nowrap;
}

.visitor-marker-content.in {
  background-color: #00C896;
}

.visitor-marker-content.out {
  background-color: #EF4444;
}

</style>