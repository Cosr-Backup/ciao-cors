import { useState, useEffect } from 'react';
import {
  Container,
  Title,
  Paper,
  TextInput,
  NumberInput,
  Switch,
  Button,
  Group,
  Tabs,
  Table,
  ActionIcon,
  Modal,
  Text,
  Badge,
  Stack,
  SimpleGrid,
} from '@mantine/core';
import { useForm } from '@mantine/form';
import { IconPlus, IconTrash, IconEdit } from '@tabler/icons-react';
import { notifications } from '@mantine/notifications';

interface Config {
  rateLimitRequests: number;
  rateLimitWindow: number;
  maxConcurrent: number;
  enableWhitelist: boolean;
  enableBlacklist: boolean;
  requireApiKey: boolean;
}

interface ListItem {
  id: string;
  type: 'ip' | 'domain';
  value: string;
  created_at: string;
}

export default function SettingsPage() {
  const [config, setConfig] = useState<Config | null>(null);
  const [blacklist, setBlacklist] = useState<ListItem[]>([]);
  const [whitelist, setWhitelist] = useState<ListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [addModal, setAddModal] = useState<{ opened: boolean; type: 'blacklist' | 'whitelist'; itemType: 'ip' | 'domain' }>({
    opened: false,
    type: 'blacklist',
    itemType: 'ip',
  });

  const form = useForm<Config>({
    initialValues: {
      rateLimitRequests: 100,
      rateLimitWindow: 3600,
      maxConcurrent: 50,
      enableWhitelist: false,
      enableBlacklist: true,
      requireApiKey: false,
    },
  });

  const addForm = useForm({
    initialValues: {
      value: '',
    },
    validate: {
      value: (value) => (value.length < 1 ? '值不能为空' : null),
    },
  });

  useEffect(() => {
    loadConfig();
    loadLists();
  }, []);

  const loadConfig = async () => {
    try {
      const response = await fetch('/api/admin/config');
      const data = await response.json();
      setConfig(data);
      form.setValues(data);
    } catch (error) {
      notifications.show({
        title: '错误',
        message: '加载配置失败',
        color: 'red',
      });
    }
  };

  const loadLists = async () => {
    try {
      const [blacklistRes, whitelistRes] = await Promise.all([
        fetch('/api/admin/blacklist'),
        fetch('/api/admin/whitelist'),
      ]);
      
      setBlacklist(await blacklistRes.json());
      setWhitelist(await whitelistRes.json());
      setLoading(false);
    } catch (error) {
      notifications.show({
        title: '错误',
        message: '加载列表失败',
        color: 'red',
      });
    }
  };

  const handleSaveConfig = async (values: Config) => {
    try {
      await fetch('/api/admin/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(values),
      });
      
      notifications.show({
        title: '成功',
        message: '配置已保存',
        color: 'green',
      });
    } catch (error) {
      notifications.show({
        title: '错误',
        message: '保存配置失败',
        color: 'red',
      });
    }
  };

  const handleAddItem = async (values: { value: string }) => {
    try {
      await fetch(`/api/admin/${addModal.type}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: addModal.itemType,
          value: values.value,
        }),
      });
      
      setAddModal({ opened: false, type: 'blacklist', itemType: 'ip' });
      addForm.reset();
      loadLists();
      
      notifications.show({
        title: '成功',
        message: '已添加到列表',
        color: 'green',
      });
    } catch (error) {
      notifications.show({
        title: '错误',
        message: '添加失败',
        color: 'red',
      });
    }
  };

  const handleRemoveItem = async (type: 'blacklist' | 'whitelist', id: string) => {
    try {
      await fetch(`/api/admin/${type}/${id}`, {
        method: 'DELETE',
      });
      
      loadLists();
      
      notifications.show({
        title: '成功',
        message: '已从列表移除',
        color: 'green',
      });
    } catch (error) {
      notifications.show({
        title: '错误',
        message: '移除失败',
        color: 'red',
      });
    }
  };

  const renderListTable = (items: ListItem[], type: 'blacklist' | 'whitelist') => (
    <Table>
      <Table.Thead>
        <Table.Tr>
          <Table.Th>类型</Table.Th>
          <Table.Th>值</Table.Th>
          <Table.Th>创建时间</Table.Th>
          <Table.Th>操作</Table.Th>
        </Table.Tr>
      </Table.Thead>
      <Table.Tbody>
        {items.map((item) => (
          <Table.Tr key={item.id}>
            <Table.Td>
              <Badge color={item.type === 'ip' ? 'blue' : 'green'}>{item.type}</Badge>
            </Table.Td>
            <Table.Td>{item.value}</Table.Td>
            <Table.Td>{new Date(item.created_at).toLocaleString()}</Table.Td>
            <Table.Td>
              <ActionIcon
                color="red"
                variant="subtle"
                onClick={() => handleRemoveItem(type, item.id)}
              >
                <IconTrash size={16} />
              </ActionIcon>
            </Table.Td>
          </Table.Tr>
        ))}
      </Table.Tbody>
    </Table>
  );

  if (loading) return <div>加载中...</div>;

  return (
    <Container fluid py="md">
      <Title order={2} mb="lg">配置管理</Title>

      <Tabs defaultValue="general">
        <Tabs.List>
          <Tabs.Tab value="general">常规设置</Tabs.Tab>
          <Tabs.Tab value="blacklist">黑名单</Tabs.Tab>
          <Tabs.Tab value="whitelist">白名单</Tabs.Tab>
        </Tabs.List>

        <Tabs.Panel value="general" pt="md">
          <Paper p="md" withBorder>
            <form onSubmit={form.onSubmit(handleSaveConfig)}>
              <Stack gap="md">
                <SimpleGrid cols={{ base: 1, sm: 2 }}>
                  <NumberInput
                    label="频率限制 (请求数)"
                    description="每个IP在指定时间窗口内的最大请求数"
                    {...form.getInputProps('rateLimitRequests')}
                  />
                  <NumberInput
                    label="时间窗口 (秒)"
                    description="频率限制的时间窗口"
                    {...form.getInputProps('rateLimitWindow')}
                  />
                </SimpleGrid>

                <NumberInput
                  label="最大并发数"
                  description="系统允许的最大并发请求数"
                  {...form.getInputProps('maxConcurrent')}
                />

                <SimpleGrid cols={{ base: 1, sm: 3 }}>
                  <Switch
                    label="启用白名单"
                    description="只允许白名单中的IP/域名访问"
                    {...form.getInputProps('enableWhitelist', { type: 'checkbox' })}
                  />
                  <Switch
                    label="启用黑名单"
                    description="阻止黑名单中的IP/域名访问"
                    {...form.getInputProps('enableBlacklist', { type: 'checkbox' })}
                  />
                  <Switch
                    label="需要API密钥"
                    description="所有请求都需要提供有效的API密钥"
                    {...form.getInputProps('requireApiKey', { type: 'checkbox' })}
                  />
                </SimpleGrid>

                <Group justify="flex-end">
                  <Button type="submit">保存配置</Button>
                </Group>
              </Stack>
            </form>
          </Paper>
        </Tabs.Panel>

        <Tabs.Panel value="blacklist" pt="md">
          <Group justify="space-between" mb="md">
            <Title order={3}>黑名单管理</Title>
            <Button
              leftSection={<IconPlus size={16} />}
              onClick={() => setAddModal({ opened: true, type: 'blacklist', itemType: 'ip' })}
            >
              添加
            </Button>
          </Group>
          {renderListTable(blacklist, 'blacklist')}
        </Tabs.Panel>

        <Tabs.Panel value="whitelist" pt="md">
          <Group justify="space-between" mb="md">
            <Title order={3}>白名单管理</Title>
            <Button
              leftSection={<IconPlus size={16} />}
              onClick={() => setAddModal({ opened: true, type: 'whitelist', itemType: 'ip' })}
            >
              添加
            </Button>
          </Group>
          {renderListTable(whitelist, 'whitelist')}
        </Tabs.Panel>
      </Tabs>

      <Modal
        opened={addModal.opened}
        onClose={() => setAddModal({ opened: false, type: 'blacklist', itemType: 'ip' })}
        title={`添加到${addModal.type === 'blacklist' ? '黑名单' : '白名单'}`}
      >
        <form onSubmit={addForm.onSubmit(handleAddItem)}>
          <Stack>
            <TextInput
              label="IP地址或域名"
              placeholder={addModal.itemType === 'ip' ? '192.168.1.1' : 'example.com'}
              required
              {...addForm.getInputProps('value')}
            />
            <Group justify="flex-end">
              <Button type="submit">添加</Button>
            </Group>
          </Stack>
        </form>
      </Modal>
    </Container>
  );
}