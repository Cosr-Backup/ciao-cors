import { NavLink } from 'react-router-dom';
import { Stack, Text, Divider } from '@mantine/core';
import { IconDashboard, IconSettings, IconKey, IconFileText } from '@tabler/icons-react';

export default function Navbar() {
  return (
    <Stack gap="xs">
      <Text fw={700} size="sm" c="dimmed" tt="uppercase">
        导航
      </Text>
      
      <NavLink
        to="/dashboard"
        style={({ isActive }) => ({
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '8px 12px',
          borderRadius: '4px',
          backgroundColor: isActive ? 'var(--mantine-color-blue-filled)' : 'transparent',
          color: isActive ? 'white' : 'inherit',
          textDecoration: 'none',
        })}
      >
        <IconDashboard size={16} />
        仪表盘
      </NavLink>

      <NavLink
        to="/dashboard/settings"
        style={({ isActive }) => ({
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '8px 12px',
          borderRadius: '4px',
          backgroundColor: isActive ? 'var(--mantine-color-blue-filled)' : 'transparent',
          color: isActive ? 'white' : 'inherit',
          textDecoration: 'none',
        })}
      >
        <IconSettings size={16} />
        配置管理
      </NavLink>

      <NavLink
        to="/dashboard/api-keys"
        style={({ isActive }) => ({
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '8px 12px',
          borderRadius: '4px',
          backgroundColor: isActive ? 'var(--mantine-color-blue-filled)' : 'transparent',
          color: isActive ? 'white' : 'inherit',
          textDecoration: 'none',
        })}
      >
        <IconKey size={16} />
        API密钥
      </NavLink>

      <NavLink
        to="/dashboard/logs"
        style={({ isActive }) => ({
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '8px 12px',
          borderRadius: '4px',
          backgroundColor: isActive ? 'var(--mantine-color-blue-filled)' : 'transparent',
          color: isActive ? 'white' : 'inherit',
          textDecoration: 'none',
        })}
      >
        <IconFileText size={16} />
        请求日志
      </NavLink>

      <Divider my="md" />
    </Stack>
  );
}