import { useState, useEffect } from 'react';
import {
  Container,
  Title,
  Paper,
  Table,
  Badge,
  Text,
  Group,
  Select,
  Pagination,
  Stack,
} from '@mantine/core';

interface LogEntry {
  id: string;
  method: string;
  url: string;
  status_code: number;
  response_time: number;
  client_ip: string;
  user_agent: string;
  created_at: string;
  api_key?: string;
}

export default function LogsPage() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [perPage] = useState(20);
  const [total, setTotal] = useState(0);

  useEffect(() => {
    loadLogs();
  }, [page]);

  const loadLogs = async () => {
    try {
      const response = await fetch(`/api/admin/recent-requests?limit=${perPage}&offset=${(page - 1) * perPage}`);
      const data = await response.json();
      setLogs(data.logs);
      setTotal(data.total);
    } catch (error) {
      console.error('加载日志失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusBadgeColor = (status: number) => {
    if (status >= 200 && status < 300) return 'green';
    if (status >= 300 && status < 400) return 'yellow';
    if (status >= 400 && status < 500) return 'orange';
    return 'red';
  };

  const formatUserAgent = (userAgent: string) => {
    if (userAgent.length > 50) {
      return userAgent.substring(0, 47) + '...';
    }
    return userAgent;
  };

  if (loading) return <div>加载中...</div>;

  return (
    <Container fluid py="md">
      <Title order={2} mb="lg">请求日志</Title>

      <Paper withBorder>
        <Table.ScrollContainer minWidth={800}>
          <Table>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>时间</Table.Th>
                <Table.Th>方法</Table.Th>
                <Table.Th>URL</Table.Th>
                <Table.Th>状态码</Table.Th>
                <Table.Th>响应时间</Table.Th>
                <Table.Th>客户端IP</Table.Th>
                <Table.Th>User Agent</Table.Th>
                <Table.Th>API密钥</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {logs.map((log) => (
                <Table.Tr key={log.id}>
                  <Table.Td>
                    <Text size="sm">{new Date(log.created_at).toLocaleString()}</Text>
                  </Table.Td>
                  <Table.Td>
                    <Badge variant="light">{log.method}</Badge>
                  </Table.Td>
                  <Table.Td>
                    <Text size="sm" style={{ maxWidth: 300 }} truncate>
                      {log.url}
                    </Text>
                  </Table.Td>
                  <Table.Td>
                    <Badge color={getStatusBadgeColor(log.status_code)}>
                      {log.status_code}
                    </Badge>
                  </Table.Td>
                  <Table.Td>
                    <Text size="sm">{log.response_time}ms</Text>
                  </Table.Td>
                  <Table.Td>
                    <Text size="sm">{log.client_ip}</Text>
                  </Table.Td>
                  <Table.Td>
                    <Text size="sm" style={{ maxWidth: 200 }}>
                      {formatUserAgent(log.user_agent)}
                    </Text>
                  </Table.Td>
                  <Table.Td>
                    {log.api_key && (
                      <Badge variant="outline" color="gray">
                        {log.api_key.substring(0, 8)}...
                      </Badge>
                    )}
                  </Table.Td>
                </Table.Tr>
              ))}
            </Table.Tbody>
          </Table>
        </Table.ScrollContainer>

        <Group justify="center" mt="md">
          <Pagination
            value={page}
            onChange={setPage}
            total={Math.ceil(total / 20)}
            siblings={1}
          />
        </Group>
      </Paper>
    </Container>
  );
}