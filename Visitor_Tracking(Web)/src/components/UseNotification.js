import { notification } from 'ant-design-vue';
import { h } from 'vue';

export function useNotification() {
  
  const showNotification = (title, body, eventtype = null) => {
    // กำหนด emoji และสีตาม eventtype
    let emoji = '🔔';
    let bgColor = '#e6f7ff';
    let borderColor = '#1890ff';

    if (eventtype === 'IN') {
      emoji = '🟢';
      bgColor = '#f6ffed';
      borderColor = '#52c41a';
    } else if (eventtype === 'OUT') {
      emoji = '🔴';
      bgColor = '#fff2f0';
      borderColor = '#ff4d4f';
    }

    notification.open({
      message: h('div', { 
        style: 'display: flex; align-items: center; gap: 10px;' 
      }, [
        // ใช้ h('span') เพื่อแสดง emoji
        h('span', { 
          style: 'font-size: 28px; line-height: 1;' 
        }, emoji),
        h('span', { 
          style: 'font-weight: 600; font-size: 15px;' 
        }, title || 'แจ้งเตือน')
      ]),
      description: body || '',
      placement: 'bottomRight',
      duration: 5,
      style: {
        width: '380px',
        backgroundColor: bgColor,
        boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
        borderRadius: '12px',
        border: `2px solid ${borderColor}`,
        padding: '16px'
      }
    });
  };

  return {
    showNotification
  };
}