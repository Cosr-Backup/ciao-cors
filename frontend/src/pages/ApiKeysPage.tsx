import { useState, useEffect } from 'react';
import {
  Container,
  Title,
  Paper,
  Button,
  Table,
  Group,
  Modal,
  TextInput,
  ActionIcon,
  Badge,
  CopyButton,
  Tooltip,
  Text,
} from '@mantine/core';
import { useForm } from '@mantine/form';
import { IconPlus, IconTrash, IconCopy, IconCheck, IconPower, IconPowerOff } from '@tabler/icons-react';
import { notifications } from '@mantine/notifications';

interface ApiKey {
  key: string;
  name: string;
  enabled: boolean;
  created_at: string;
  usage_count: number;
  last_used: string | null;
}

export default function ApiKeysPage() {
  const [keys, setKeys] = useState<ApiKey[]>([]);
  const [loading, setLoading] = useState(true);
  const [addModal, setAddModal] = useState(false);

  const form = useForm({
    initialValues: {
      name: '',
    },
    validate: {
      name: (value) => (value.length < 1 ? '名称不能为空' : null),
    },
  });

  useEffect(() => {
    loadKeys();
  }, []);

  const loadKeys = async () => {
    try {
      const response = await fetch('/api/admin/api-keys');
      const data = await response.json();
      setKeys(data);
    } catch (error) {
      notifications.show({
        title: '错误',
        message: '加载API密钥失败',
        color: 'red',
      });
    } finally {
      setLoading(false);
    }
  };

  const handleGenerateKey = async (values: { name: string }) => {
    try {
      const response = await fetch('/api/admin/api-keys', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(values),
      });
      
      const data = await response.json();
      setKeys([...keys, data]);
      setAddModal(false);
      form.reset();
      
      notifications.show({
        title: '成功',
        message: `API密钥已生成: ${data.key}`,
        color: 'green',
      });
    } catch (error) {
      notifications.show({
        title: '错误',
        message: '生成API密钥失败',
        color: 'red',
      });
    }
  };

  const handleToggleKey = async (key: string, enabled: boolean) => {
    try {
      const endpoint = enabled ? 'disable' : 'enable';
      await fetch(`/api/admin/api-keys/${key}/${endpoint}`, {
        method: 'POST',
      });
      
      setKeys(keys.map(k => k.key === key ? { ...k, enabled: !enabled } : k));
      
      notifications.show({
        title: '成功',
        message: `API密钥已${enabled ? '禁用' : '启用'}`,
        color: 'green',
      });
    } catch (error) {
      notifications.show({
        title: '错误',
        message: '操作失败',
        color: 'red',
      });
    }
  };

  const handleRevokeKey = async (key: string) => {
    try {
      await fetch(`/api/admin/api-keys/${key}`, {
        method: 'DELETE',
      });
      
      setKeys(keys.filter(k => k.key !== key));
      
      notifications.show({
        title: '成功',
        message: 'API密钥已撤销',
        color: 'green',
      });
    } catch (error) {
      notifications.show({
        title: '错误',
        message: '撤销API密钥失败',
        color: 'red',
      });
    }
  };

  if (loading) return <div>加载中...</div>;

  return (
    <Container fluid py="md">
      <Group justify="space-between" mb="lg">
        <Title order={2}>API密钥管理</Title>
        <Button leftSection={<IconPlus size={16} />} onClick={() => setAddModal(true)}>
          生成新密钥
        </Button>
      </Group>

      <Paper withBorder>
        <Table>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>名称</Table.Th>
              <Table.Th>密钥</Table.Th>
              <Table.Th>状态</Table.Th>
              <Table.Th>使用次数</Table.Th>
              <Table.Th>创建时间</Table.Th>
              <Table.Th>最后使用</Table.Th>
              <Table.Th>操作</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {keys.map((key) => (
              <Table.Tr key={key.key}>
                <Table.Td>
                  <Text fw={500}>{key.name}</Text>
                </Table.Td>
                <Table.Td>
                  <Group gap="xs">
                    <Code>{key.key}</Code>
                    <CopyButton value={key.key} timeout={2000}>
                      {({ copied, copy }) => (
                        <Tooltip label={copied ? '已复制' : '复制'}>
                          <ActionIcon color={copied ? 'teal' : 'gray'} onClick={copy}>
                            {copied ? <IconCheck size={16} /> : <IconCopy size={16} />}
                          </ActionIcon>
                        </Tooltip>
                      )}
                    </CopyButton>
                  </Group>
                </Table.Td>
                <Table.Td>
                  <Badge color={key.enabled ? 'green' : 'red'}>
                    {key.enabled ? '启用' : '禁用'}
                  </Badge>
                </Table.Td>
                <Table.Td>{key.usage_count}</Table.Td>
                <Table.Td>{new Date(key.created_at).toLocaleString()}</Table.Td>
                <Table.Td>
                  {key.last_used ? new Date(key.last_used).toLocaleString() : '从未使用'}
                </Table.Td>
                <Table.Td>
                  <Group gap="xs">
                    <ActionIcon
                      color={key.enabled ? 'red' : 'green'}
                      variant="subtle"
                      onClick={() => handleToggleKey(key.key, key.enabled)}
                    >
                      {key.enabled ? <IconPowerOff size={16} /> : <IconPower size={16} />}
                    </ActionIcon>
                    <ActionIcon
                      color="red"
                      variant="subtle"
                      onClick={() => handleRevokeKey(key.key)}
                    >
                      <IconTrash size={16} />
                    </ActionIcon>
                  </Group>
                </Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      </Paper>

      <Modal
        opened={addModal}
        onClose={() => setAddModal(false)}
        title="生成API密钥"
      >
        <form onSubmit={form.onSubmit(handleGenerateKey)}>
          <Stack>
            <TextInput
              label="名称"
              placeholder="输入密钥名称"
              required
              {...form.getInputProps('name')}
            />
            <Group justify="flex-end">
              <Button type="submit">生成</Button>
            </Group>
          </Stack>
        </form>
      </Modal>
    </Container>
  );
}